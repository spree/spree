import type { CatalogProduct } from '@spree/admin-sdk'
import type { ProductMembershipRow } from '@spree/dashboard-ui'
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
export function catalogPriceColumns({
  products,
  headers,
}: {
  /** The server rows this page rendered, which carry the resolved price. */
  products: CatalogProduct[]
  headers: {
    price: string
    source: string
  }
}) {
  const byId = new Map(products.map((product) => [product.id, product.catalog_price]))

  return {
    headers: (
      <>
        <TableHead className="w-32 text-right">{headers.price}</TableHead>
        <TableHead className="w-28">{headers.source}</TableHead>
      </>
    ),
    renderCells: (row: ProductMembershipRow) => {
      const price = row.pending === 'added' ? undefined : byId.get(row.id)

      return (
        <>
          <TableCell className="text-right tabular-nums">
            {price ? (
              price.display_amount
            ) : (
              <span className="text-muted-foreground">
                {row.pending === 'added'
                  ? i18n.t('admin.catalogs.prices.after_save')
                  : i18n.t('admin.catalogs.prices.unpriced')}
              </span>
            )}
          </TableCell>
          <TableCell>{price && <PriceSourceBadge source={price.source} />}</TableCell>
        </>
      )
    },
  }
}

/**
 * A price the agreement decided reads as an ordinary fact; one falling
 * through to the shop price is called out, because a merchant looking at a
 * catalog has every reason to assume it prices what it lists.
 */
function PriceSourceBadge({ source }: { source: string }) {
  const fromAgreement = (AGREEMENT_SOURCES as readonly string[]).includes(source)
  const help = i18n.t(`admin.catalogs.prices.source_help.${source}`)

  return (
    <Tooltip>
      <TooltipTrigger asChild>
        {/* Focusable and named, so the explanation opens on focus as well as
            hover — the same reason the terms columns wrap theirs. */}
        <button type="button" className="cursor-help rounded-sm" aria-label={help}>
          <Badge variant={fromAgreement ? 'secondary' : 'outline'}>
            {i18n.t(`admin.catalogs.prices.source.${source}`)}
          </Badge>
        </button>
      </TooltipTrigger>
      <TooltipContent className="max-w-xs">{help}</TooltipContent>
    </Tooltip>
  )
}
