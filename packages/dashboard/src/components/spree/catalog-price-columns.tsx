import type { CatalogPrice } from '@spree/admin-sdk'
import type { ProductMembershipRow, SubRowLayout } from '@spree/dashboard-ui'
import {
  Badge,
  TableCell,
  TableHead,
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from '@spree/dashboard-ui'
import i18n from 'i18next'

const AGREEMENT_SOURCES = ['explicit', 'automatic'] as const

/** Where the copy comes from: the catalog's strings, or a page's own. */
const CATALOG_NAMESPACE = 'admin.catalogs.prices'

/**
 * A string for these columns. A page that reads them on another record — a
 * price list's own page — supplies a namespace whose keys say "this list"
 * where the catalog's say "this catalog", and everything it does not
 * override falls back to the catalog's copy.
 */
function text(namespace: string, key: string, options?: Record<string, unknown>) {
  return i18n.t([`${namespace}.${key}`, `${CATALOG_NAMESPACE}.${key}`], options ?? {})
}

/**
 * What the agreement charges, as columns on the assortment rows.
 *
 * The source is the reason these columns exist: an amount on its own cannot
 * tell a merchant whether their catalog actually prices a product or is
 * quietly falling through to the shop price. A `base` row is exactly that
 * divergence — in the assortment, priced by nothing the agreement says
 * (docs/plans/6.0-catalog-agreement-rework.md).
 *
 * A staged addition has no resolved price yet — it does not exist server-side
 * until Save — so it says so rather than borrowing another row's number. A
 * staged removal keeps showing its price: it is still on the list until Save,
 * and the struck-through row already says it is leaving.
 */
/** Columns `catalogPriceColumns` contributes, and a variant sub-row fills itself. */
const CATALOG_PRICE_COLUMN_COUNT = 2

export function catalogPriceColumns({
  headers,
  namespace = CATALOG_NAMESPACE,
}: {
  headers: {
    price: string
    source: string
  }
  /** Copy namespace; see `text`. */
  namespace?: string
}) {
  return {
    columnCount: CATALOG_PRICE_COLUMN_COUNT,
    headers: (
      <>
        <TableHead className="w-32 text-right">{headers.price}</TableHead>
        <TableHead className="w-28">{headers.source}</TableHead>
      </>
    ),
    // The product row carries no price: its variants can be priced
    // differently and carry different ladders, so one figure here would name
    // a single variant's deal and hide the rest
    // (docs/plans/6.0-volume-pricing.md). The rows beneath say it per variant.
    renderCells: (row: ProductMembershipRow) => (
      <>
        <TableCell className="text-right text-muted-foreground text-xs">
          {row.pending === 'added' ? text(namespace, 'after_save') : null}
        </TableCell>
        <TableCell />
      </>
    ),
  }
}

/**
 * A price the agreement decided reads as an ordinary fact; one falling
 * through to the shop price is called out, because a merchant looking at a
 * catalog has every reason to assume it prices what it lists.
 */
function PriceSourceBadge({ source, namespace }: { source: string; namespace: string }) {
  const fromAgreement = (AGREEMENT_SOURCES as readonly string[]).includes(source)
  const help = text(namespace, `source_help.${source}`)

  return (
    <Tooltip>
      <TooltipTrigger asChild>
        {/* Focusable and named, so the explanation opens on focus as well as
            hover — the same reason the terms columns wrap theirs. */}
        <button type="button" className="cursor-help rounded-sm" aria-label={help}>
          <Badge variant={fromAgreement ? 'secondary' : 'outline'}>
            {text(namespace, `source.${source}`)}
          </Badge>
        </button>
      </TooltipTrigger>
      <TooltipContent className="max-w-xs">{help}</TooltipContent>
    </Tooltip>
  )
}

/**
 * The count of a variant's quantity tiers, with the ladder itself on hover.
 *
 * The count alone asks a merchant to open the price sheet to read three
 * figures, which is a click to answer a question the row could just answer
 * (docs/plans/6.0-volume-pricing.md).
 */
function TierBadge({ price, namespace }: { price: CatalogPrice; namespace: string }) {
  const label = text(namespace, 'tier_count', { count: price.break_count })

  // Nothing to preview — either the resolver could not price the rungs, or
  // the response predates the field (a client holding a cached page across
  // a deploy). Either way the badge stays a plain statement of fact rather
  // than taking the row down with it.
  const tiers = price.tiers ?? []
  if (tiers.length === 0) {
    return (
      <Badge variant="outline" className="font-normal">
        {label}
      </Badge>
    )
  }

  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <button type="button" className="cursor-help rounded-sm">
          <Badge variant="outline" className="font-normal">
            {label}
          </Badge>
        </button>
      </TooltipTrigger>
      {/* TooltipContent is an inline-flex row capped at 200px, which lays a
          heading beside a table and wraps both. A ladder is a block: stack it
          and let it size to its figures. */}
      <TooltipContent className="max-w-none flex-col items-stretch gap-0 px-2.5 py-2 text-left">
        <p className="mb-1.5 whitespace-nowrap font-medium">{text(namespace, 'tier_preview')}</p>
        <table className="text-xs tabular-nums">
          <tbody>
            {/* The variant's own price is the ladder's first rung, so the
                preview opens with it rather than starting at the first
                break — otherwise the cheapest figure reads as the price. */}
            <tr>
              <td className="whitespace-nowrap pr-4 text-muted-foreground">
                {text(namespace, 'tier_from', { count: 1 })}
              </td>
              <td className="whitespace-nowrap text-right">{price.display_amount}</td>
            </tr>
            {tiers.map((tier) => (
              <tr key={tier.min_quantity}>
                <td className="whitespace-nowrap pr-4 text-muted-foreground">
                  {text(namespace, 'tier_from', { count: tier.min_quantity })}
                </td>
                <td className="whitespace-nowrap text-right">{tier.display_amount}</td>
              </tr>
            ))}
          </tbody>
        </table>
        {/* A ladder fixes the price: the catalog's percentage adjustment is
            never applied on top of an explicit row, and this is where a
            merchant who set both would otherwise expect to see it
            (docs/plans/6.0-volume-pricing.md). */}
        <p className="mt-1.5 max-w-56 text-muted-foreground text-xs">
          {text(namespace, 'tier_fixed_note')}
        </p>
      </TooltipContent>
    </Tooltip>
  )
}

/**
 * A product's variants as rows beneath it, each with what this agreement
 * charges for it and the ladder behind that figure.
 *
 * Variants are where prices actually live — a product's can differ, and each
 * carries its own quantity breaks — so the agreement is only readable when
 * they are listed individually (docs/plans/6.0-volume-pricing.md).
 *
 * @param products the server rows for this page, which carry the resolved
 *   per-variant prices
 */
export function catalogVariantRows<Row extends { id: string }>({
  products,
  variantsOf,
  namespace = CATALOG_NAMESPACE,
}: {
  products: Row[]
  /** The resolved per-variant prices a server row carries. */
  variantsOf: (product: Row) => CatalogPrice[] | undefined
  /** Copy namespace; see `text`. */
  namespace?: string
}) {
  const byId = new Map(products.map((product) => [product.id, variantsOf(product) ?? []]))

  return (
    row: ProductMembershipRow,
    { leadingCells, extraColumnCount, trailingCells }: SubRowLayout,
  ) => {
    // A variant row fills this set's own columns (price, source); every other
    // set's columns belong to the product and are spanned.
    const spannedCells = Math.max(extraColumnCount - CATALOG_PRICE_COLUMN_COUNT, 0) + trailingCells
    // A staged addition has no server row yet, so it has nothing to list.
    const variants = row.pending === 'added' ? [] : (byId.get(row.id) ?? [])
    if (variants.length === 0) return null

    return variants.map((price) => (
      <tr key={price.id} className="border-b text-sm last:border-b-0">
        {/* One spanning cell rather than several empty ones: these are
            spacers to line the row up, not columns of their own. */}
        {leadingCells > 0 && <TableCell colSpan={leadingCells} />}
        {/* The name gives up space last: a flex item's default minimum is its
            own content, so both halves have to be told they may shrink, and
            the SKU is told to shrink first — it identifies the variant only
            once the name already has. */}
        <TableCell className="max-w-0 text-muted-foreground">
          <span className="flex min-w-0 items-center gap-2 pl-11">
            <span className="shrink-[1] truncate">
              {price.label ?? text(namespace, 'variant_default')}
            </span>
            {price.sku && (
              <span className="min-w-0 shrink-[4] truncate font-mono text-xs opacity-70">
                {price.sku}
              </span>
            )}
          </span>
        </TableCell>
        <TableCell className="text-right tabular-nums">
          <span className="inline-flex items-center justify-end gap-1.5">
            {price.display_amount}
            {price.break_count > 0 && <TierBadge price={price} namespace={namespace} />}
          </span>
        </TableCell>
        <TableCell>
          <PriceSourceBadge source={price.source} namespace={namespace} />
        </TableCell>
        {/* The quantity-term columns and the row-action column, spanned
            rather than filled: terms are stated per product, so a variant row
            has nothing to say in them. Counted from the table's own layout so
            the row can never come up short and stretch the table. */}
        {spannedCells > 0 && <TableCell colSpan={spannedCells} />}
      </tr>
    ))
  }
}
