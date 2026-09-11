import type { StockLevel } from '@spree/admin-sdk'
import { adminClient, ResourceTable, resourceSearchSchema } from '@spree/dashboard-core'
import { createFileRoute } from '@tanstack/react-router'
import '../../../../tables/stock-levels'

export const Route = createFileRoute('/_authenticated/$storeId/inventory/')({
  validateSearch: resourceSearchSchema,
  component: InventoryPage,
})

function InventoryPage() {
  const search = Route.useSearch()

  return (
    <ResourceTable<StockLevel>
      tableKey="stock-levels"
      queryKey="stock-levels"
      queryFn={(params) => adminClient.stockLevels.list(params)}
      searchParams={search}
    />
  )
}
