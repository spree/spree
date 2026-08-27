import { type ResourceSearch, resourceSearchSchema } from '@spree/dashboard-core'
import { createFileRoute } from '@tanstack/react-router'
import { PoliciesPage } from '../../../../pages/policies'

export const Route = createFileRoute('/_authenticated/$sellerId/settings/policies')({
  validateSearch: resourceSearchSchema,
  component: PoliciesRoute,
})

function PoliciesRoute() {
  const search = Route.useSearch() as ResourceSearch

  return <PoliciesPage search={search} />
}
