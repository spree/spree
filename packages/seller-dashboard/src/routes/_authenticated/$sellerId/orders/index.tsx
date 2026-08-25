import { type ResourceSearch, resourceSearchSchema } from '@spree/dashboard-core'
import { createFileRoute } from '@tanstack/react-router'
import { OrdersPage } from '../../../../pages/orders'

export const Route = createFileRoute('/_authenticated/$sellerId/orders/')({
  validateSearch: resourceSearchSchema,
  component: OrdersRoute,
})

function OrdersRoute() {
  // Cast: the inferred type unions with the parent layout's shape.
  const search = Route.useSearch() as ResourceSearch

  return <OrdersPage search={search} />
}
