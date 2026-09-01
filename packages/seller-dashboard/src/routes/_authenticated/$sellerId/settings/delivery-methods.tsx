import { type ResourceSearch, resourceSearchSchema } from '@spree/dashboard-core'
import { createFileRoute } from '@tanstack/react-router'
import { DeliveryMethodsPage } from '../../../../pages/delivery-methods'

export const Route = createFileRoute('/_authenticated/$sellerId/settings/delivery-methods')({
  validateSearch: resourceSearchSchema,
  component: DeliveryMethodsRoute,
})

function DeliveryMethodsRoute() {
  const search = Route.useSearch() as ResourceSearch

  return <DeliveryMethodsPage search={search} />
}
