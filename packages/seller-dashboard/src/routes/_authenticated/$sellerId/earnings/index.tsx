import { type ResourceSearch, resourceSearchSchema } from '@spree/dashboard-core'
import { createFileRoute } from '@tanstack/react-router'
import { EarningsPage } from '../../../../pages/earnings'

/** What this seller has earned: their balance, then the ledger behind it. */
export const Route = createFileRoute('/_authenticated/$sellerId/earnings/')({
  validateSearch: resourceSearchSchema,
  component: EarningsRoute,
})

function EarningsRoute() {
  const search = Route.useSearch() as ResourceSearch

  return <EarningsPage search={search} />
}
