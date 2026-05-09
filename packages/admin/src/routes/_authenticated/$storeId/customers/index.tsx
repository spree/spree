import { createFileRoute } from '@tanstack/react-router'
import { adminClient } from '@/client'
import { ExportButton } from '@/components/spree/export-button'
import { ResourceTable, resourceSearchSchema } from '@/components/spree/resource-table'
import '@/tables/customers'

export const Route = createFileRoute('/_authenticated/$storeId/customers/')({
  validateSearch: resourceSearchSchema,
  component: CustomersPage,
})

function CustomersPage() {
  const searchParams = Route.useSearch()

  return (
    <ResourceTable
      tableKey="customers"
      queryKey="customers"
      queryFn={(params) => adminClient.customers.list(params)}
      searchParams={searchParams}
      actions={(ctx) => <ExportButton type="Spree::Exports::Customers" {...ctx} />}
    />
  )
}
