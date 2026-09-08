import { useStore } from '@spree/dashboard-core'
import { Thumbnail } from '@spree/dashboard-ui'
import { PackageIcon } from '@spree/dashboard-ui/icons'
import { Link } from '@tanstack/react-router'

/**
 * A document line's variant — its image, its name linked to the product that
 * owns it, and optionally its SKU underneath.
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
  const label = name ?? '—'

  return (
    <div className="flex items-center gap-3">
      <Thumbnail src={thumbnailUrl} fallback={<PackageIcon />} />
      <div className="min-w-0">
        {productId ? (
          <Link
            to="/$storeId/products/$productId"
            params={{ storeId, productId }}
            className="font-medium hover:underline"
          >
            {label}
          </Link>
        ) : (
          <span className="font-medium">{label}</span>
        )}
        {sku && <span className="block text-muted-foreground text-xs">{sku}</span>}
      </div>
    </div>
  )
}
