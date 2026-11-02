import { type ResourceSearch, resourceSearchSchema } from '@spree/dashboard-core'
import { createFileRoute } from '@tanstack/react-router'
import { InvoicesPage } from '../../../../pages/invoices'

/** This seller's invoices and the marketplace's commission invoices. */
export const Route = createFileRoute('/_authenticated/$sellerId/invoices/')({
  validateSearch: resourceSearchSchema,
  component: InvoicesRoute,
})

function InvoicesRoute() {
  const search = Route.useSearch() as ResourceSearch

  return <InvoicesPage search={search} />
}
