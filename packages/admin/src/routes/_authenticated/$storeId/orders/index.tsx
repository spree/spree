import { createFileRoute, Link } from '@tanstack/react-router'
import { PlusIcon } from 'lucide-react'
import { adminClient } from '@/client'
import { ExportButton } from '@/components/spree/export-button'
import { ResourceTable, resourceSearchSchema } from '@/components/spree/resource-table'
import { Button } from '@/components/ui/button'
import '@/tables/orders'

export const Route = createFileRoute('/_authenticated/$storeId/orders/')({
  validateSearch: resourceSearchSchema,
  component: OrdersPage,
})

function OrdersPage() {
  const searchParams = Route.useSearch()
  const { storeId } = Route.useParams()

  return (
    <ResourceTable
      tableKey="orders"
      queryKey="orders"
      queryFn={(params) => adminClient.orders.list(params)}
      searchParams={searchParams}
      defaultParams={{ complete: 1 }}
      actions={(ctx) => (
        <>
          <ExportButton type="Spree::Exports::Orders" {...ctx} />
          <Button size="sm" className="h-[2.125rem]" asChild>
            <Link to="/$storeId/orders/new" params={{ storeId }}>
              <PlusIcon className="size-4" />
              New Order
            </Link>
          </Button>
        </>
      )}
    />
  )
}
