import {
  adminClient,
  ExportButton,
  ResourceTable,
  resourceSearchSchema,
} from '@spree/dashboard-core'
import { Button } from '@spree/dashboard-ui'
import { PlusIcon } from '@spree/dashboard-ui/icons'
import { createFileRoute, Link } from '@tanstack/react-router'
import '../../../../tables/orders'

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
      defaultParams={{ complete: 1, expand: ['channel'] }}
      actions={(ctx) => (
        <>
          <ExportButton type="orders" {...ctx} />
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
