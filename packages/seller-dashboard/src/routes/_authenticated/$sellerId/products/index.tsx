import { type ResourceSearch, resourceSearchSchema } from '@spree/dashboard-core'
import { createFileRoute } from '@tanstack/react-router'
import { ProductsPage } from '../../../../pages/products'

export const Route = createFileRoute('/_authenticated/$sellerId/products/')({
  validateSearch: resourceSearchSchema,
  component: ProductsRoute,
})

function ProductsRoute() {
  // Cast: the inferred type unions with the parent layout's shape.
  const search = Route.useSearch() as ResourceSearch

  return <ProductsPage search={search} />
}
