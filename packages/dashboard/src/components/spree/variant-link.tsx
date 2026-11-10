import { useStore } from '@spree/dashboard-core'
import {
  ProductIdentity,
  type ProductIdentityProps,
  type ProductLinkRender,
} from '@spree/dashboard-ui'
import { Link } from '@tanstack/react-router'

/**
 * A product or variant in a list, linked to the product that owns it — image
 * and name together.
 *
 * Renders plain when there is no product. A document line outlives the
 * variant it names, so a discontinued SKU still has to appear on the transfer
 * or order that shipped it.
 */
export function VariantLink({
  productId,
  sku,
  ...props
}: Omit<ProductIdentityProps, 'render'> & {
  productId?: string | null
  sku?: string | null
}) {
  const { storeId } = useStore()

  return (
    <ProductIdentity
      subtitle={sku}
      {...props}
      render={
        productId ? (
          <Link to="/$storeId/products/$productId" params={{ storeId, productId }} />
        ) : undefined
      }
    />
  )
}

/** Links an item list's products to their pages in this panel. */
export function useProductLink(): ProductLinkRender {
  const { storeId } = useStore()
  return (productId) => <Link to="/$storeId/products/$productId" params={{ storeId, productId }} />
}
