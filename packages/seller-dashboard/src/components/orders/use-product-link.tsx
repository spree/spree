import type { ProductLinkRender } from '@spree/dashboard-ui'
import { Link, useParams } from '@tanstack/react-router'

/** Links an item list's products to the seller's own product pages. */
export function useProductLink(): ProductLinkRender {
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })
  return (productId) => (
    <Link to="/$sellerId/products/$productId" params={{ sellerId, productId }} />
  )
}
