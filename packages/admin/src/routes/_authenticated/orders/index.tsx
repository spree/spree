import { createFileRoute } from '@tanstack/react-router'
import { PlusIcon } from 'lucide-react'
import { adminClient } from '@/client'
import { ResourceTable, resourceSearchSchema } from '@/components/resource-table'
import { Button } from '@/components/ui/button'
import '@/tables/orders'

export const Route = createFileRoute('/_authenticated/orders/')({
  validateSearch: resourceSearchSchema,
  component: OrdersPage,
})

function OrdersPage() {
  const searchParams = Route.useSearch()

  return (
    <ResourceTable
      tableKey="orders"
      queryKey="orders"
      queryFn={(params) => adminClient.orders.list(params)}
      searchParams={searchParams}
      defaultParams={{ complete: 1 }}
      actions={
        <Button size="sm" className="h-[2.125rem]">
          <PlusIcon className="size-4" />
          New Order
        </Button>
      }
    />
  )
}
