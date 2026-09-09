import { type ResourceSearch, resourceSearchSchema } from '@spree/dashboard-core'
import { createFileRoute } from '@tanstack/react-router'
import { PayoutsPage } from '../../../../pages/payouts'

export const Route = createFileRoute('/_authenticated/$sellerId/payouts/')({
  validateSearch: resourceSearchSchema,
  component: PayoutsRoute,
})

function PayoutsRoute() {
  const search = Route.useSearch() as ResourceSearch

  return <PayoutsPage search={search} />
}
