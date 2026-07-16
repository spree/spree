/**
 * File route for the brand detail page — demonstrates a path param
 * (`$brandId`) as a first-class, typed route: `<Link>`s to it are checked
 * against the host's generated route tree, no casts needed.
 */
import { createFileRoute } from '@tanstack/react-router'
import { BrandDetailPage } from '../pages/brand-detail'

export const Route = createFileRoute('/_authenticated/$storeId/brands/$brandId')({
  component: BrandDetailRoute,
})

function BrandDetailRoute() {
  const { brandId } = Route.useParams()
  return <BrandDetailPage brandId={brandId} />
}
