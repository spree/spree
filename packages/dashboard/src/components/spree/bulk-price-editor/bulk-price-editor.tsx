import type { PriceBulkUpsertRow } from '@spree/admin-sdk'
import {
  Button,
  DataGrid,
  editableRowIndex,
  Input,
  MoneyCell,
  ReadOnlyCell,
} from '@spree/dashboard-ui'
import { useQuery } from '@tanstack/react-query'
import type { ColumnDef } from '@tanstack/react-table'
import { useCallback, useDeferredValue, useEffect, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { adminClient } from '@/client'
import { useBulkUpsertPrices } from '@/hooks/use-prices'

const PAGE_SIZE = 50

interface PriceRowState {
  id: string
  kind: 'header' | 'item'
  productName?: string
  productId?: string
  priceId?: string
  variantId?: string
  variantLabel?: string | null
  sku?: string | null
  amount?: string | null
  compareAt?: string | null
}

interface PriceListRowFromServer {
  id: string
  variant_id: string
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
  amount: string | null
  compareAt: string | null
}

type FilterShape = Record<string, string | number | boolean | null | undefined>

// Strip predicates the editor owns + drop empty values, then serialize
// in a key-sorted form so reference churn from the parent doesn't
// trigger spurious refetches / edits resets but real shape changes do.
function sanitizeFilter(filter: FilterShape | undefined): FilterShape {
  if (!filter) return {}
  const out: FilterShape = {}
  for (const [k, v] of Object.entries(filter)) {
    if (k.startsWith('price_list_id')) continue
    if (v === undefined || v === null || v === '') continue
    out[k] = v
  }
  return out
}

function stableFilterKey(filter: FilterShape): string {
  const entries = Object.entries(filter).sort(([a], [b]) => a.localeCompare(b))
  return entries.length === 0 ? '' : JSON.stringify(entries)
}

function currencyParts(currencyCode: string, locale: string): { symbol: string; decimal: string } {
  try {
    const parts = new Intl.NumberFormat(locale, {
      style: 'currency',
      currency: currencyCode,
    }).formatToParts(1234.56)
    return {
      symbol: parts.find((p) => p.type === 'currency')?.value ?? currencyCode,
      decimal: parts.find((p) => p.type === 'decimal')?.value ?? '.',
    }
  } catch {
    return { symbol: currencyCode, decimal: '.' }
  }
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
  filter?: Record<string, string | number | boolean | null | undefined>
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
 * Generic prices spreadsheet. Reads via `GET /admin/prices?…&expand=variant`
 * (server-side pagination, SKU search) and saves via
 * `POST /admin/prices/bulk_upsert`. Filters are owned by the caller so
 * the same component drives both the "edit one price list" route and a
 * future "edit base prices" route.
 */
export function BulkPriceEditor({
  priceListId,
  currency,
  filter,
  onStateChange,
}: BulkPriceEditorProps) {
  const { t, i18n } = useTranslation()
  // Destructure the stable handles off `useMutation` (mutateAsync is
  // stable across renders; the wrapper object is not). Closing over the
  // wrapper would put a fresh reference in every callback's dep array
  // and tank the parent via the `onStateChange` effect below.
  const { mutateAsync: bulkUpsertAsync, isPending: isSaving } = useBulkUpsertPrices()
  const [page, setPage] = useState(1)
  const [search, setSearch] = useState('')
  const deferredSearch = useDeferredValue(search)

  const sanitizedFilter = useMemo(() => sanitizeFilter(filter), [filter])
  const filterKey = useMemo(() => stableFilterKey(sanitizedFilter), [sanitizedFilter])

  const { symbol, decimal } = useMemo(
    () => currencyParts(currency, i18n.language || 'en'),
    [currency, i18n.language],
  )

  const { data, isLoading } = useQuery({
    queryKey: [
      'prices',
      { priceListId: priceListId ?? null, currency, filter: filterKey, page, q: deferredSearch },
    ],
    queryFn: () =>
      adminClient.prices.list({
        // Caller-supplied predicates first, then the editor's own — the
        // sanitizer above strips any `price_list_id_*` keys so callers
        // can't override our scope distinction.
        ...sanitizedFilter,
        ...(priceListId ? { price_list_id_eq: priceListId } : { price_list_id_null: true }),
        currency_eq: currency,
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

  const baselineRows = useMemo<PriceRowState[]>(() => {
    if (!data) return []
    const out: PriceRowState[] = []
    let lastProductId: string | null = null
    for (const row of data.data as unknown as PriceListRowFromServer[]) {
      const variant = row.variant ?? {}
      if (variant.product_id && variant.product_id !== lastProductId) {
        out.push({
          id: `header:${variant.product_id}`,
          kind: 'header',
          productName: variant.product_name,
          productId: variant.product_id,
        })
        lastProductId = variant.product_id
      }
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
    }
    return out
  }, [data])

  const [edits, setEdits] = useState<Map<string, CellEdit>>(() => new Map())

  // Reset page + edits whenever the upstream filters change — a different
  // list, currency, or product scope is a different working set; carrying
  // old edits across would be confusing and could collide on the
  // bulk-upsert ids.
  // biome-ignore lint/correctness/useExhaustiveDependencies: reset is bound to filter identity
  useEffect(() => {
    setPage(1)
    setEdits(new Map())
  }, [priceListId, currency, filterKey])

  const rows = useMemo<PriceRowState[]>(
    () =>
      baselineRows.map((r) => {
        if (r.kind !== 'item' || !r.priceId) return r
        const edit = edits.get(r.priceId)
        if (!edit) return r
        return { ...r, amount: edit.amount, compareAt: edit.compareAt }
      }),
    [baselineRows, edits],
  )

  const setCell = useCallback(
    (priceId: string, field: 'amount' | 'compareAt', next: string | null) => {
      setEdits((prev) => {
        const baseline = baselineRows.find(
          (r): r is PriceRowState & { kind: 'item' } => r.kind === 'item' && r.priceId === priceId,
        )
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
        const current = prev.get(priceId) ?? {
          variantId: baseline.variantId,
          amount: displayBaseAmount,
          compareAt: displayBaseCompare,
        }
        const merged = { ...current, [field]: next }
        if (merged.amount === displayBaseAmount && merged.compareAt === displayBaseCompare) {
          const out = new Map(prev)
          out.delete(priceId)
          return out
        }
        const out = new Map(prev)
        out.set(priceId, merged)
        return out
      })
    },
    [baselineRows, decimal],
  )

  const save = useCallback(async (): Promise<boolean> => {
    if (edits.size === 0) return false
    // Snapshot the keys we're about to ship; cells stay editable while
    // the mutation is in-flight, so concurrent edits the user makes
    // during the round-trip must survive the post-save clear. After a
    // successful upsert we drop only the keys that were in the snapshot.
    const savedKeys = Array.from(edits.keys())
    // Ship the unique-key triple `(variant_id, currency, price_list_id)`
    // — that's what the server upserts on. `id` is not used by the bulk
    // endpoint; we already have the lookup columns on screen so there's
    // no point making the server backfill them.
    const payload: PriceBulkUpsertRow[] = savedKeys.map((priceId) => {
      const edit = edits.get(priceId) as CellEdit
      return {
        variant_id: edit.variantId,
        currency,
        ...(priceListId ? { price_list_id: priceListId } : {}),
        amount: edit.amount,
        compare_at_amount: edit.compareAt,
      }
    })
    try {
      const res = await bulkUpsertAsync({ prices: payload })
      toast.success(
        t('admin.pages.products.price_lists.edit_prices.save_success', { count: res.price_count }),
      )
      setEdits((prev) => {
        const out = new Map(prev)
        for (const key of savedKeys) out.delete(key)
        return out
      })
      return true
    } catch (err) {
      const message =
        err instanceof Error
          ? err.message
          : t('admin.pages.products.price_lists.edit_prices.save_failed')
      toast.error(message)
      return false
    }
  }, [edits, currency, priceListId, bulkUpsertAsync, t])

  const discard = useCallback(() => {
    setEdits(new Map())
  }, [])

  // Surface dirty/save/discard to the parent route so it can render a
  // sticky footer and gate router navigation on unsaved edits.
  useEffect(() => {
    onStateChange?.({ dirtyCount: edits.size, saving: isSaving, save, discard })
  }, [edits.size, isSaving, save, discard, onStateChange])

  const columns = useMemo<ColumnDef<PriceRowState>[]>(
    () => [
      {
        id: 'variant',
        header: t('admin.pages.products.price_lists.edit_prices.columns.variant'),
        cell: ({ row }) => {
          const r = row.original
          if (r.kind !== 'item') return null
          return (
            <ReadOnlyCell className="text-muted-foreground">
              {r.variantLabel ?? t('admin.pages.products.price_lists.edit_prices.variant_default')}
            </ReadOnlyCell>
          )
        },
      },
      {
        id: 'sku',
        header: t('admin.pages.products.price_lists.edit_prices.columns.sku'),
        cell: ({ row }) => {
          const r = row.original
          if (r.kind !== 'item') return null
          return (
            <ReadOnlyCell className="font-mono text-xs text-muted-foreground">
              {r.sku ?? '—'}
            </ReadOnlyCell>
          )
        },
      },
      {
        id: 'amount',
        header: () => (
          <span className="block text-right">
            {t('admin.pages.products.price_lists.edit_prices.columns.price')}
          </span>
        ),
        cell: ({ row, table }) => {
          const r = row.original
          if (r.kind !== 'item') return null
          const coords = { row: editableRowIndex(table.getRowModel().rows, row.id), col: 2 }
          const label =
            r.variantLabel ?? t('admin.pages.products.price_lists.edit_prices.variant_default')
          return (
            <MoneyCell
              coords={coords}
              value={r.amount ?? null}
              onChange={(next) => r.priceId && setCell(r.priceId, 'amount', next)}
              symbol={symbol}
              decimal={decimal}
              ariaLabel={t('admin.pages.products.price_lists.edit_prices.price_aria', { label })}
            />
          )
        },
      },
      {
        id: 'compare_at',
        header: () => (
          <span className="block text-right">
            {t('admin.pages.products.price_lists.edit_prices.columns.compare_at_price')}
          </span>
        ),
        cell: ({ row, table }) => {
          const r = row.original
          if (r.kind !== 'item') return null
          const coords = { row: editableRowIndex(table.getRowModel().rows, row.id), col: 3 }
          const label =
            r.variantLabel ?? t('admin.pages.products.price_lists.edit_prices.variant_default')
          return (
            <MoneyCell
              coords={coords}
              value={r.compareAt ?? null}
              onChange={(next) => r.priceId && setCell(r.priceId, 'compareAt', next)}
              symbol={symbol}
              decimal={decimal}
              ariaLabel={t('admin.pages.products.price_lists.edit_prices.compare_at_aria', {
                label,
              })}
            />
          )
        },
      },
    ],
    [symbol, decimal, setCell, t],
  )

  const isEmpty = !isLoading && rows.length === 0

  return (
    <div className="flex h-full flex-col gap-3">
      {/* Always-mounted toolbar. Conditionally rendering the search
          input would unmount it mid-keystroke whenever the deferred
          query refetches into the loading state, blurring the field
          and dropping the user's text cursor. */}
      <div className="flex shrink-0 items-center justify-between gap-3">
        <p className="text-xs text-muted-foreground">
          {totalCount > 0
            ? t('admin.pages.products.price_lists.edit_prices.count_summary', {
                count: totalCount,
                currency,
              })
            : t('admin.pages.products.price_lists.edit_prices.no_matches_for_filters')}
        </p>
        <Input
          type="search"
          placeholder={t('admin.pages.products.price_lists.edit_prices.search_placeholder')}
          value={search}
          onChange={(e) => {
            setSearch(e.target.value)
            setPage(1)
          }}
          className="h-9 max-w-sm"
        />
      </div>

      {/* The flex-1 + min-h-0 combo lets the grid scroll within its
          container instead of pushing the toolbar/pagination off-screen.
          Loading and empty states fill the same space so the dialog
          never visually collapses around small content. */}
      <div className="min-h-0 flex-1 overflow-auto">
        {isLoading ? (
          <p className="text-sm text-muted-foreground">{t('admin.common.loading')}</p>
        ) : isEmpty ? (
          <p className="text-sm text-muted-foreground">
            {search
              ? t('admin.pages.products.price_lists.edit_prices.no_matches_for_search', { search })
              : priceListId
                ? t('admin.pages.products.price_lists.edit_prices.empty_pick_products')
                : t('admin.pages.products.price_lists.edit_prices.empty_no_base_prices')}
          </p>
        ) : (
          <DataGrid<PriceRowState>
            rows={rows}
            columns={columns}
            getRowId={(row) => row.id}
            renderSectionHeader={(row) =>
              row.kind === 'header' ? (
                <div className="truncate font-medium">{row.productName}</div>
              ) : null
            }
            aria-label={t('admin.pages.products.price_lists.edit_prices.grid_aria')}
          />
        )}
      </div>

      {totalPages > 1 && (
        <div className="flex shrink-0 items-center justify-between gap-2 text-xs text-muted-foreground">
          <span>{t('admin.common.page_of', { page, total: totalPages })}</span>
          <div className="flex gap-1">
            <Button
              type="button"
              size="sm"
              variant="outline"
              onClick={() => setPage((p) => Math.max(1, p - 1))}
              disabled={page === 1 || isLoading}
            >
              {t('admin.common.prev')}
            </Button>
            <Button
              type="button"
              size="sm"
              variant="outline"
              onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
              disabled={page === totalPages || isLoading}
            >
              {t('admin.common.next')}
            </Button>
          </div>
        </div>
      )}
    </div>
  )
}
