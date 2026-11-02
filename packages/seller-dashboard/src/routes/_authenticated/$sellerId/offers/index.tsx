import { type ResourceSearch, resourceSearchSchema } from '@spree/dashboard-core'
import { createFileRoute } from '@tanstack/react-router'
import { OffersPage } from '../../../../pages/offers'

export const Route = createFileRoute('/_authenticated/$sellerId/offers/')({
  validateSearch: resourceSearchSchema,
  component: OffersRoute,
})

function OffersRoute() {
  const search = Route.useSearch() as ResourceSearch

  return <OffersPage search={search} />
}
