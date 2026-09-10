import { useStore } from '@spree/dashboard-core'
import { Thumbnail } from '@spree/dashboard-ui'
import { PackageIcon } from '@spree/dashboard-ui/icons'
import { Link } from '@tanstack/react-router'

/**
 * A document line's variant — its image, its name and optionally its SKU —
 * the whole of it linked to the product that owns it, so a merchant can aim
 * at the picture as readily as the name.
 *
 * Renders plain text when the line names no product. A line outlives the
 * variant it names — the same way the movement ledger outlives the level it
 * describes — so a discontinued SKU still has to appear on the transfer or
 * order that shipped it.
 */
export function VariantLink({
  productId,
  name,
  sku,
  thumbnailUrl,
}: {
  productId?: string | null
  name?: string | null
  sku?: string | null
  thumbnailUrl?: string | null
}) {
  const { storeId } = useStore()

  const body = (
    <>
      <Thumbnail src={thumbnailUrl} fallback={<PackageIcon />} />
      <div className="min-w-0">
        <span className="font-medium group-hover:underline">{name ?? '—'}</span>
        {sku && <span className="block text-muted-foreground text-xs">{sku}</span>}
      </div>
    </>
  )

  if (!productId) return <div className="flex items-center gap-3">{body}</div>

  return (
    <Link
      to="/$storeId/products/$productId"
      params={{ storeId, productId }}
      className="group flex items-center gap-3"
    >
      {body}
    </Link>
  )
}
