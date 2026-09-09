import type { PriceBulkUpsertRow } from '@spree/admin-sdk'
import {
  adminClient,
  currencyParts,
  normalizeMoneyInput,
  useResourceKey,
} from '@spree/dashboard-core'
import { type BulkPriceRow, BulkPriceTable, toastManager } from '@spree/dashboard-ui'
import { useQuery } from '@tanstack/react-query'
import { useCallback, useDeferredValue, useEffect, useMemo, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useCurrencyLocale } from '../../../hooks/use-currency-locale'
import { useBulkUpsertPrices } from '../../../hooks/use-prices'
import { MAXIMUM_QUANTITY_TIERS } from '../../../schemas/price-list'

const PAGE_SIZE = 50
// The API caps a page at 100 rows, so the break sweep asks for exactly that
// and pages until it has them all — at most one page per ten variants on
// screen, since a variant carries at most ten breaks.
const BREAK_PAGE_SIZE = 100
const MAX_BREAK_PAGES = Math.ceil((PAGE_SIZE * MAXIMUM_QUANTITY_TIERS) / BREAK_PAGE_SIZE)

interface PriceListRowFromServer {
  id: string
  variant_id: string
  min_quantity: number
  amount: string | null
  compare_at_amount: string | null
  variant?: {
    product_id?: string
    product_name?: string
    options_text?: string | null
    sku?: string | null
  }
}

interface CellEdit {
  // Stash the variantId at write time. Without it, edits made on page 2
  // would lose their identifier as soon as the user paginates back to
  // page 1: the save loop resolves variant_id via `baselineRows`, which
  // only holds the current page's server result.
  variantId: string
  // Present on a quantity break, absent on the variant's own price — which
  // is the ladder's bottom rung and needs no quantity on the wire.
  minQuantity?: string
  amount: string | null
  compareAt: string | null
  // Set only by the row's remove control. A blank amount is how the bulk
  // endpoint is told to drop a rung, so it is also what a half-typed row
  // looks like — this is what tells the two apart.
  removing?: true
  // The quantity this rung is stored under, when the merchant has since
  // changed it. The bulk endpoint keys on the quantity, so a moved rung is an
  // insert at the new one — the row at the old quantity has to be cleared by
  // name or the ladder keeps both (docs/plans/6.0-volume-pricing.md).
  storedMinQuantity?: string
}

// BulkPriceRow extended with the server-side variantId so save can ship the
// canonical (variant_id, currency, price_list_id, min_quantity) upsert key.
interface BaselineRow extends BulkPriceRow {
  priceId?: string
  variantId?: string
}

// A break the merchant added that has no stored row yet. Carries its own
// client id so the grid can key it before the server assigns one.
interface DraftRung {
  id: string
  variantId: string
  minQuantity: string
  amount: string | null
}

type FilterShape = Record<string, string | number | boolean | string[] | null | undefined>

// Strip predicates the editor owns + drop empty values, then serialize
// in a key-sorted form so reference churn from the parent doesn't
// trigger spurious refetches / edits resets but real shape changes do.
function sanitizeFilter(filter: FilterShape | undefined): FilterShape {
  if (!filter) return {}
  const out: FilterShape = {}
  for (const [k, v] of Object.entries(filter)) {
    if (k.startsWith('price_list_id')) continue
    if (v === undefined || v === null || v === '') continue
    // An empty list is not a filter — Ransack reads `field_in: []` as
    // "match nothing" and would blank the grid.
    if (Array.isArray(v) && v.length === 0) continue
    out[k] = v
  }
  return out
}

function stableFilterKey(filter: FilterShape): string {
  const entries = Object.entries(filter).sort(([a], [b]) => a.localeCompare(b))
  return entries.length === 0 ? '' : JSON.stringify(entries)
}

export interface BulkPriceEditorProps {
  /** Filter by a specific price list. Omit to edit base prices. */
  priceListId?: string
  currency: string
  /** Extra Ransack predicates spread into the index call — e.g.
   *  `{ variant_product_id_eq: 'prod_xxx' }` for a per-product editor.
   *  Keys starting with `price_list_id` are stripped (the editor owns
   *  that predicate via `priceListId`). Memoize in the parent to avoid
   *  refetch + edits-reset churn on every render. */
  filter?: FilterShape
  /** Notifies the parent of dirty count + save handle so the route can
   *  render a sticky footer bar and a router-leave guard. */
  onStateChange?: (state: BulkPriceEditorState) => void
}

export interface BulkPriceEditorState {
  dirtyCount: number
  saving: boolean
  /** Resolves to `true` if the upsert succeeded, `false` on error (the
   *  editor already toasted) or no-op (nothing dirty). Lets the dialog
   *  decide whether to close without inspecting post-save state. */
  save: () => Promise<boolean>
  discard: () => void
}

/**
 * Server-backed prices spreadsheet. Reads via `GET /admin/prices?…&expand=variant`
 * (server-side pagination, SKU search) and saves via
 * `POST /admin/prices/bulk_upsert`. Filters are owned by the caller so
 * the same component drives both the "edit one price list" route and a
 * "edit base prices for one product" dialog. Presentation is delegated
 * to `<BulkPriceTable>` from `@spree/dashboard-ui`.
 */
export function BulkPriceEditor({
  priceListId,
  currency,
  filter,
  onStateChange,
}: BulkPriceEditorProps) {
  const { t } = useTranslation()
  // Destructure the stable handles off `useMutation` (mutateAsync is
  // stable across renders; the wrapper object is not). Closing over the
  // wrapper would put a fresh reference in every callback's dep array
  // and tank the parent via the `onStateChange` effect below.
  const { mutateAsync: bulkUpsertAsync, isPending: isSaving } = useBulkUpsertPrices(priceListId)
  const localeForCurrency = useCurrencyLocale()
  const [page, setPage] = useState(1)
  const [search, setSearch] = useState('')
  const deferredSearch = useDeferredValue(search)

  const sanitizedFilter = useMemo(() => sanitizeFilter(filter), [filter])
  const filterKey = useMemo(() => stableFilterKey(sanitizedFilter), [sanitizedFilter])

  // Format the grid in the currency's market locale (e.g. EUR → `de`, comma
  // decimal). The same locale normalizes amounts to canonical form on save (see
  // `save`), so what the merchant types matches what the API receives. Falls
  // back to `en` (canonical period-decimal), NOT the UI language — money
  // formatting/parsing must never depend on the dashboard's language.
  const marketLocale = localeForCurrency(currency) || 'en'
  const { symbol, decimal } = useMemo(
    () => currencyParts(currency, marketLocale),
    [currency, marketLocale],
  )

  const { data, isLoading } = useQuery({
    queryKey: useResourceKey('prices', {
      priceListId: priceListId ?? null,
      currency,
      filter: filterKey,
      page,
      q: deferredSearch,
    }),
    queryFn: () =>
      adminClient.prices.list({
        // Caller-supplied predicates first, then the editor's own — the
        // sanitizer above strips any `price_list_id_*` keys so callers
        // can't override our scope distinction.
        ...sanitizedFilter,
        ...(priceListId ? { price_list_id_eq: priceListId } : { price_list_id_null: true }),
        currency_eq: currency,
        // One row per variant: the deeper rungs of a ladder are edited in
        // the tier dialog, not as extra lines that read like duplicates
        // (docs/plans/6.0-volume-pricing.md).
        min_quantity_eq: 1,
        // `search` is a Ransack-whitelisted scope on Price that ORs
        // across the variant's SKU, parent product name, and option-value
        // presentations ("Red", "XL", …). 3-char floor lives in the scope.
        search: deferredSearch || undefined,
        expand: 'variant',
        page,
        limit: PAGE_SIZE,
        sort: 'variant_product_name,variant_id',
      } as never),
    enabled: !!currency,
  })

  const totalPages = data?.meta?.pages ?? 1
  const totalCount = data?.meta?.count ?? 0

  const pageVariantIds = useMemo(
    () =>
      ((data?.data ?? []) as unknown as PriceListRowFromServer[])
        .map((row) => row.variant_id)
        .filter(Boolean),
    [data],
  )

  // The rungs above the bottom one, for this page's variants only — a few
  // queries rather than one per row, and none at all when this editor has no
  // list to hold a ladder (docs/plans/6.0-volume-pricing.md).
  //
  // Paged rather than asked for in one call: a page of fifty fully-laddered
  // variants is five hundred rows and the API caps a page at a hundred, so a
  // single request would silently truncate and under-report the badges.
  const { data: breakRows } = useQuery({
    queryKey: useResourceKey('prices', {
      breaks: priceListId ?? null,
      currency,
      variants: pageVariantIds.join(','),
    }),
    queryFn: async () => {
      const collected: PriceListRowFromServer[] = []
      let breakPage = 1
      let lastPage: number

      do {
        const response = await adminClient.prices.list({
          variant_id_in: pageVariantIds,
          price_list_id_eq: priceListId,
          currency_eq: currency,
          min_quantity_gt: 1,
          page: breakPage,
          limit: BREAK_PAGE_SIZE,
        } as never)

        collected.push(...(response.data as unknown as PriceListRowFromServer[]))
        lastPage = response.meta?.pages ?? 1
        breakPage += 1
        // Bounded: a page of variants can hold at most PAGE_SIZE ladders of
        // MAXIMUM_QUANTITY_TIERS rungs, so anything beyond that is a server
        // answering something this loop should not chase.
      } while (breakPage <= lastPage && breakPage <= MAX_BREAK_PAGES)

      return collected
    },
    enabled: !!priceListId && pageVariantIds.length > 0,
  })

  // Grouped by variant and ordered by quantity, so a ladder renders in the
  // order it is read (docs/plans/6.0-volume-pricing.md).
  const breaksByVariant = useMemo(() => {
    const grouped = new Map<string, PriceListRowFromServer[]>()
    for (const row of breakRows ?? []) {
      const rungs = grouped.get(row.variant_id) ?? []
      rungs.push(row)
      grouped.set(row.variant_id, rungs)
    }
    for (const rungs of grouped.values()) rungs.sort((a, b) => a.min_quantity - b.min_quantity)
    return grouped
  }, [breakRows])

  // Rungs added in this session that have no stored row yet. They live beside
  // the fetched ones until Save writes them.
  const [draftRungs, setDraftRungs] = useState<DraftRung[]>([])
  // Monotonic, so two rungs added in the same millisecond cannot collide.
  const nextDraftId = useRef(0)
  // Which blank rows have already become drafts, by blank-row id. A blank row
  // keeps its id once promoted — the next one gets a fresh id from the row
  // builder — so this is what keeps a second keystroke from adding a
  // second rung.
  const promotedBlankRows = useRef(new Map<string, string>())

  const baselineRows = useMemo<BaselineRow[]>(() => {
    if (!data) return []
    const out: BaselineRow[] = []
    let lastProductId: string | null = null
    for (const row of data.data as unknown as PriceListRowFromServer[]) {
      const variant = row.variant ?? {}
      if (variant.product_id && variant.product_id !== lastProductId) {
        out.push({
          id: `header:${variant.product_id}`,
          kind: 'header',
          groupLabel: variant.product_name,
        })
        lastProductId = variant.product_id
      }
      const rungs = breaksByVariant.get(row.variant_id) ?? []

      out.push({
        id: row.id,
        kind: 'item',
        priceId: row.id,
        variantId: row.variant_id,
        variantLabel: variant.options_text ?? null,
        sku: variant.sku ?? null,
        amount: row.amount,
        compareAt: row.compare_at_amount,
      })

      // The rungs are ordinary rows of this sheet. A variant's own price is
      // the ladder's first rung — which is why quantity is a column and these
      // are simply the rows below it (docs/plans/6.0-volume-pricing.md).
      for (const rung of rungs) {
        out.push({
          id: rung.id,
          kind: 'tier',
          priceId: rung.id,
          variantId: row.variant_id,
          minQuantity: String(rung.min_quantity),
          amount: rung.amount,
        })
      }

      // A draft whose quantity the server already returns is the same rung
      // twice: the stored row above renders it, so this one steps aside until
      // the effect drops it. Skipping rather than removing is what keeps the
      // handover from flickering (docs/plans/6.0-volume-pricing.md).
      const storedQuantities = new Set(rungs.map((rung) => rung.min_quantity))

      for (const draft of draftRungs.filter((entry) => entry.variantId === row.variant_id)) {
        if (storedQuantities.has(Number(draft.minQuantity))) continue

        out.push({
          id: draft.id,
          kind: 'tier',
          variantId: row.variant_id,
          minQuantity: draft.minQuantity,
          amount: draft.amount,
        })
      }

      // Every variant ends with an empty rung waiting to be typed into, so
      // growing a ladder is filling in the next line rather than asking for
      // one first (docs/plans/6.0-volume-pricing.md).
      //
      // The id counts the drafts already added, so each new blank row is a
      // distinct row rather than the promoted one wearing its old name.
      const draftCount = draftRungs.filter((entry) => entry.variantId === row.variant_id).length
      out.push({
        id: `blank:${row.variant_id}:${draftCount}`,
        kind: 'tier',
        blank: true,
        variantId: row.variant_id,
        minQuantity: '',
        amount: null,
      })
    }
    return out
  }, [data, breaksByVariant, draftRungs])

  const [edits, setEdits] = useState<Map<string, CellEdit>>(() => new Map())
  // Keys already written to the server, kept in `edits` until the refetch
  // carries their values — see the release effect below.
  const [savedPending, setSavedPending] = useState<Set<string>>(() => new Set())

  // Reset page + edits whenever the upstream filters change — a different
  // list, currency, or product scope is a different working set; carrying
  // old edits across would be confusing and could collide on the
  // bulk-upsert ids.
  // biome-ignore lint/correctness/useExhaustiveDependencies: reset is bound to filter identity
  useEffect(() => {
    setPage(1)
    setEdits(new Map())
    setSavedPending(new Set())
    setDraftRungs([])
  }, [priceListId, currency, filterKey])

  // Releases a saved edit once the refetched row agrees with it, so the cell
  // hands over to server data without ever showing the value it replaced.
  // Compared on the canonical decimal, since the edit holds the merchant's
  // locale-formatted input.
  useEffect(() => {
    if (savedPending.size === 0) return

    const settled: string[] = []
    for (const key of savedPending) {
      const edit = edits.get(key)
      // Gone already (discarded, or the working set changed) — stop tracking.
      if (!edit) {
        settled.push(key)
        continue
      }

      const baseline = baselineRows.find((row) => (row.priceId ?? row.id) === key)
      if (!baseline) continue

      const saved = normalizeMoneyInput(edit.amount ?? '', marketLocale || 'en')
      if ((baseline.amount ?? '') === (saved === '' ? '' : saved)) settled.push(key)
    }
    if (settled.length === 0) return

    setEdits((prev) => {
      const out = new Map(prev)
      for (const key of settled) out.delete(key)
      return out
    })
    setSavedPending((prev) => {
      const out = new Set(prev)
      for (const key of settled) out.delete(key)
      return out
    })
  }, [baselineRows, edits, savedPending, marketLocale])

  // Hands a saved draft over to the row the server now returns, once that row
  // has actually arrived. Doing this on save instead would blank the rung for
  // the length of the refetch — the row someone just entered disappearing and
  // coming back (docs/plans/6.0-volume-pricing.md).
  useEffect(() => {
    if (draftRungs.length === 0) return

    const stored = new Set((breakRows ?? []).map((row) => `${row.variant_id}:${row.min_quantity}`))
    const pending = draftRungs.filter(
      (rung) => !stored.has(`${rung.variantId}:${Number(rung.minQuantity)}`),
    )
    if (pending.length === draftRungs.length) return

    setDraftRungs(pending)
    // The blank rows below them are re-keyed by the draft count, so the
    // promotion bookkeeping for the old ids is spent.
    promotedBlankRows.current = new Map()
  }, [breakRows, draftRungs])

  const rows = useMemo<BulkPriceRow[]>(
    () =>
      baselineRows.map((r) => {
        if (r.kind === 'header') return r
        const edit = edits.get(r.priceId ?? r.id)
        if (!edit) return r
        // A tier row edits the same two things a variant row does, minus the
        // compare-at it has no column for. Its quantity comes from the edit
        // too: a stored rung renders the server's number, so leaving it out
        // meant a retyped quantity was overwritten by the old one the moment
        // the cell left edit mode.
        return r.kind === 'tier'
          ? { ...r, minQuantity: edit.minQuantity, amount: edit.amount }
          : { ...r, amount: edit.amount, compareAt: edit.compareAt }
      }),
    [baselineRows, edits],
  )

  // Typing in a variant's trailing blank row turns it into a real draft rung,
  // and the row builder immediately puts a fresh blank one below it — so the
  // ladder always has somewhere to grow (docs/plans/6.0-volume-pricing.md).
  //
  // @returns the draft's id, so the caller can record the edit against it
  const promoteBlankRow = useCallback((rowId: string): string | null => {
    if (!rowId.startsWith('blank:')) return null

    // Idempotent per blank row: typing a quantity and then a price both reach
    // here, and promoting twice would leave the merchant with two rungs where
    // they entered one (docs/plans/6.0-volume-pricing.md).
    const existing = promotedBlankRows.current.get(rowId)
    if (existing) return existing

    // `blank:<variantId>:<draftCount>` — the count keeps successive blank
    // rows distinct, so it is dropped when reading the variant back out.
    const variantId = rowId.slice('blank:'.length).replace(/:\d+$/, '')
    const draftId = `draft:${variantId}:${nextDraftId.current++}`
    promotedBlankRows.current.set(rowId, draftId)
    setDraftRungs((prev) => [...prev, { id: draftId, variantId, minQuantity: '', amount: null }])
    return draftId
  }, [])

  const handleChange = useCallback(
    (rowId: string, field: 'amount' | 'compareAt', next: string | null) => {
      // Typing a price into the trailing blank row is what creates the rung.
      const promoted = promoteBlankRow(rowId)
      const targetId = promoted ?? rowId

      setEdits((prev) => {
        // A draft rung has no stored row, so it is found by its own id.
        const baseline = baselineRows.find((r) => (r.priceId ?? r.id) === rowId)
        if (!baseline?.variantId) return prev
        // Baseline is the API's canonical decimal (`12.50`); the cell
        // ships the user's raw locale-formatted input (`12,50`). Seed the
        // baseline in display form so an untouched field naturally matches
        // when the other field is edited — otherwise an edit to `compareAt`
        // alone would falsely mark `amount` dirty under a comma-decimal locale.
        const displayBaseAmount = baseline.amount ? baseline.amount.replace('.', decimal) : null
        const displayBaseCompare = baseline.compareAt
          ? baseline.compareAt.replace('.', decimal)
          : null
        const current = prev.get(targetId) ?? {
          variantId: baseline.variantId,
          minQuantity: baseline.minQuantity,
          amount: displayBaseAmount,
          compareAt: displayBaseCompare,
        }
        // An edit already holding a quantity keeps it: the merchant may have
        // typed the quantity first, and the baseline still says what the
        // server last stored. Only a rung with no edit yet takes its quantity
        // from the row.
        const merged = {
          ...current,
          minQuantity: prev.get(targetId)?.minQuantity ?? baseline.minQuantity,
          [field]: next,
          // Blanking the price of a rung the server already has is how it is
          // deleted, the same as the row's remove control. On a rung that was
          // never stored there is nothing to delete — it is simply unfinished,
          // and the save refuses it rather than reporting a removal.
          ...(field === 'amount'
            ? { removing: !next && baseline.priceId ? (true as const) : undefined }
            : {}),
        }
        if (merged.amount === displayBaseAmount && merged.compareAt === displayBaseCompare) {
          const out = new Map(prev)
          out.delete(targetId)
          return out
        }
        const out = new Map(prev)
        out.set(targetId, merged)
        return out
      })
    },
    [baselineRows, decimal, promoteBlankRow],
  )

  // The plus on the blank row does the same thing a keystroke does — it is
  // there for discoverability, not because a row has to be asked for.
  const addTier = useCallback(
    (rowId: string) => {
      promoteBlankRow(rowId)
    },
    [promoteBlankRow],
  )

  const changeTierQuantity = useCallback(
    (rowId: string, value: string) => {
      const promoted = promoteBlankRow(rowId)
      const targetId = promoted ?? rowId

      setDraftRungs((prev) =>
        prev.map((rung) => (rung.id === targetId ? { ...rung, minQuantity: value } : rung)),
      )
      setEdits((prev) => {
        const row = baselineRows.find((entry) => (entry.priceId ?? entry.id) === rowId)
        if (!row?.variantId) return prev

        const existing = prev.get(targetId)
        const out = new Map(prev)
        // The quantity the server has for this rung, remembered from the
        // first edit so retyping the cell repeatedly still clears the one
        // original row rather than the previous keystroke's value.
        const stored = existing?.storedMinQuantity ?? (row.priceId ? row.minQuantity : undefined)
        // Moving a stored rung's quantity is an edit in its own right, and a
        // draft's quantity is what makes it addressable at all — so either
        // way the row joins the sheet's unsaved changes.
        out.set(targetId, {
          variantId: row.variantId,
          minQuantity: value,
          amount: existing?.amount ?? row.amount ?? null,
          compareAt: existing?.compareAt ?? null,
          // Back at its original quantity there is nothing to clear.
          ...(stored && stored !== value ? { storedMinQuantity: stored } : {}),
        })
        return out
      })
    },
    [baselineRows, promoteBlankRow],
  )

  const removeTier = useCallback(
    (rowId: string) => {
      // A draft rung has nothing stored to remove; a saved one is cleared by
      // sending a blank amount, which the bulk endpoint reads as "delete this".
      if (rowId.startsWith('draft:')) {
        setDraftRungs((prev) => prev.filter((rung) => rung.id !== rowId))
        setEdits((prev) => {
          const out = new Map(prev)
          out.delete(rowId)
          return out
        })
        return
      }

      setEdits((prev) => {
        const row = baselineRows.find((entry) => entry.priceId === rowId)
        if (!row?.variantId) return prev

        const out = new Map(prev)
        out.set(rowId, {
          variantId: row.variantId,
          minQuantity: row.minQuantity,
          amount: null,
          compareAt: null,
          removing: true,
        })
        return out
      })
    },
    [baselineRows],
  )

  const save = useCallback(async (): Promise<boolean> => {
    if (edits.size === 0) return false
    // Snapshot the keys we're about to ship; cells stay editable while
    // the mutation is in-flight, so concurrent edits the user makes
    // during the round-trip must survive the post-save clear. After a
    // successful upsert we drop only the keys that were in the snapshot.
    // A rung the merchant started and left empty is not a price — it carries
    // neither a quantity nor an amount, and the server would refuse it.
    const savedKeys = Array.from(edits.entries())
      // Already written and waiting for their refetch — re-sending them would
      // write the same values again on every subsequent save.
      .filter(([id]) => !savedPending.has(id))
      .filter(([id, edit]) => !(id.startsWith('draft:') && !edit.minQuantity && !edit.amount))
      .map(([id]) => id)
    if (savedKeys.length === 0) return false

    // A rung with a quantity but no price is unfinished, not a deletion. The
    // bulk endpoint reads a blank amount as "remove this rung", so sending it
    // would answer a half-typed row by quietly discarding it — with a success
    // toast (docs/plans/6.0-volume-pricing.md). Say what is missing instead.
    const incomplete = savedKeys.find((key) => {
      const edit = edits.get(key)
      return edit != null && !edit.removing && Boolean(edit.minQuantity) && !edit.amount
    })
    if (incomplete) {
      toastManager.add({
        type: 'error',
        title: t('admin.pages.products.price_lists.edit_prices.tier_needs_price', {
          quantity: edits.get(incomplete)?.minQuantity ?? '',
        }),
      })
      return false
    }
    // Ship the unique-key triple `(variant_id, currency, price_list_id)`
    // — that's what the server upserts on. `id` is not used by the bulk
    // endpoint; we already have the lookup columns on screen so there's
    // no point making the server backfill them.
    // Normalize each amount from the grid's display locale (the currency's
    // market locale, e.g. EUR → `de`) into the canonical `"1234.56"` the API
    // expects. The server is never asked to parse comma-vs-period — see
    // docs/plans/5.5-client-side-money-normalization.md.
    const toCanonical = (v: string | null) => {
      if (v == null) return null
      const normalized = normalizeMoneyInput(v, marketLocale || 'en')
      return normalized === '' ? null : normalized
    }
    const payload: PriceBulkUpsertRow[] = savedKeys.flatMap((priceId) => {
      const edit = edits.get(priceId) as CellEdit
      const row: PriceBulkUpsertRow = {
        variant_id: edit.variantId,
        currency,
        ...(priceListId ? { price_list_id: priceListId } : {}),
        // Absent on a variant's own price, which is the ladder's bottom rung.
        ...(edit.minQuantity ? { min_quantity: Number(edit.minQuantity) } : {}),
        amount: toCanonical(edit.amount),
        // A break carries no compare-at; sending one would claim a former
        // price for a contracted figure.
        ...(edit.minQuantity ? {} : { compare_at_amount: toCanonical(edit.compareAt) }),
      }
      // A rung whose quantity moved is an insert at the new one, since that
      // is what the endpoint keys on — so the row it left behind is cleared
      // in the same batch, or the merchant ends up with the rung twice.
      if (!edit.storedMinQuantity) return [row]
      return [
        row,
        {
          variant_id: edit.variantId,
          currency,
          ...(priceListId ? { price_list_id: priceListId } : {}),
          min_quantity: Number(edit.storedMinQuantity),
          amount: null,
        },
      ]
    })
    try {
      const res = await bulkUpsertAsync({ prices: payload })
      toastManager.add({
        type: 'success',
        title: t('admin.pages.products.price_lists.edit_prices.save_success', {
          count: res.price_count,
        }),
      })
      // Neither the edits nor the drafts are cleared here. Both are released
      // once the refetch actually carries the saved values (see the effects
      // below). Clearing now would show every saved cell its stale baseline
      // — and unmount a new rung entirely — for the length of the round
      // trip, which reads as the sheet flashing back and forth
      // (docs/plans/6.0-volume-pricing.md).
      setSavedPending((prev) => new Set([...prev, ...savedKeys]))
      return true
    } catch (err) {
      const message =
        err instanceof Error
          ? err.message
          : t('admin.pages.products.price_lists.edit_prices.save_failed')
      toastManager.add({ type: 'error', title: message })
      return false
    }
  }, [edits, savedPending, currency, priceListId, bulkUpsertAsync, marketLocale, t])

  const discard = useCallback(() => {
    setEdits(new Map())
    setSavedPending(new Set())
    setDraftRungs([])
  }, [])

  // Held edits are already written, so they are not unsaved changes —
  // counting them would leave the header claiming work that is done.
  const dirtyCount = useMemo(
    () => Array.from(edits.keys()).filter((key) => !savedPending.has(key)).length,
    [edits, savedPending],
  )

  // Surface dirty/save/discard to the parent route so it can render a
  // sticky footer and gate router navigation on unsaved edits.
  useEffect(() => {
    onStateChange?.({ dirtyCount, saving: isSaving, save, discard })
  }, [dirtyCount, isSaving, save, discard, onStateChange])

  const countSummary =
    totalCount > 0
      ? t('admin.pages.products.price_lists.edit_prices.count_summary', {
          count: totalCount,
          currency,
        })
      : t('admin.pages.products.price_lists.edit_prices.no_matches_for_filters')

  const emptyMessage = priceListId
    ? t('admin.pages.products.price_lists.edit_prices.empty_pick_products')
    : t('admin.pages.products.price_lists.edit_prices.empty_no_base_prices')

  const emptySearchMessage = t(
    'admin.pages.products.price_lists.edit_prices.no_matches_for_search',
    { search },
  )

  return (
    <BulkPriceTable
      rows={rows}
      symbol={symbol}
      decimal={decimal}
      onChange={handleChange}
      // Ladders live on a price list; base prices carry no breaks in v1, so
      // neither the quantity column nor the rung rows appear there.
      onTierQuantityChange={priceListId ? changeTierQuantity : undefined}
      onTierAdd={priceListId ? addTier : undefined}
      onTierRemove={priceListId ? removeTier : undefined}
      search={search}
      onSearchChange={(next) => {
        setSearch(next)
        setPage(1)
      }}
      page={page}
      totalPages={totalPages}
      onPageChange={setPage}
      isLoading={isLoading}
      labels={{
        variant: t('admin.pages.products.price_lists.edit_prices.columns.variant'),
        sku: t('admin.pages.products.price_lists.edit_prices.columns.sku'),
        price: t('admin.pages.products.price_lists.edit_prices.columns.price'),
        compareAt: t('admin.pages.products.price_lists.edit_prices.columns.compare_at_price'),
        variantDefault: t('admin.pages.products.price_lists.edit_prices.variant_default'),
        searchPlaceholder: t('admin.pages.products.price_lists.edit_prices.search_placeholder'),
        countSummary,
        loading: t('admin.common.loading'),
        pageOf: t('admin.common.page_of', { page: '{page}', total: '{total}' }),
        prev: t('admin.common.prev'),
        next: t('admin.common.next'),
        emptyMessage,
        emptySearchMessage,
        gridAriaLabel: t('admin.pages.products.price_lists.edit_prices.grid_aria'),
        priceAriaTemplate: t('admin.pages.products.price_lists.edit_prices.price_aria', {
          label: '{label}',
        }),
        compareAtAriaTemplate: t('admin.pages.products.price_lists.edit_prices.compare_at_aria', {
          label: '{label}',
        }),
        tierFrom: priceListId ? t('admin.pages.products.price_lists.tiers.from') : undefined,
        tierAdd: t('admin.pages.products.price_lists.tiers.add'),
        tierRemove: t('admin.pages.products.price_lists.tiers.remove_short'),
        tierQuantity: t('admin.pages.products.price_lists.tiers.quantity'),
      }}
    />
  )
}
