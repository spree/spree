import type { StockLevel } from '@spree/admin-sdk'
import { adminClient, ResourceTable, resourceSearchSchema } from '@spree/dashboard-core'
import { useRowClickBridge } from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import '../../../../tables/stock-levels'

export const Route = createFileRoute('/_authenticated/$storeId/inventory/')({
  validateSearch: resourceSearchSchema,
  component: InventoryPage,
})

function InventoryPage() {
  const { storeId } = Route.useParams()
  const search = Route.useSearch()
  const navigate = useNavigate()

  // A level is a variant at a location, and the variant lives on its product
  // page — that is where the row goes.
  useRowClickBridge('data-stock-level-product-id', (productId) => {
    navigate({ to: '/$storeId/products/$productId', params: { storeId, productId } })
  })

  return (
    <ResourceTable<StockLevel>
      tableKey="stock-levels"
      queryKey="stock-levels"
      queryFn={(params) => adminClient.stockLevels.list(params)}
      searchParams={search}
    />
  )
}
