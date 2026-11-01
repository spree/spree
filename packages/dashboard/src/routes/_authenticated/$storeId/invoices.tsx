import {
  adminClient,
  ExportButton,
  ResourceTable,
  resourceSearchSchema,
} from '@spree/dashboard-core'
import { createFileRoute } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import '../../../tables/invoices'

export const Route = createFileRoute('/_authenticated/$storeId/invoices')({
  validateSearch: resourceSearchSchema,
  component: InvoicesPage,
})

/**
 * Every invoice in the store, for accountants. Invoices are uploaded and acted
 * on from the order or seller payout they belong to, so this list is read-only.
 */
function InvoicesPage() {
  const { t } = useTranslation()
  const searchParams = Route.useSearch()

  return (
    <ResourceTable
      tableKey="invoices"
      queryKey="invoices"
      queryFn={(params) => adminClient.invoices.list(params)}
      searchParams={searchParams}
      title={t('admin.nav.invoices')}
      actions={(ctx) => <ExportButton type="invoices" {...ctx} />}
    />
  )
}
