import { createFileRoute } from '@tanstack/react-router'
import { PlusIcon } from 'lucide-react'
import { spreeClient } from '@/client'
import { ResourceTable, resourceSearchSchema } from '@/components/resource-table'
import { Button } from '@/components/ui/button'
import { useAuth } from '@/hooks/use-auth'
import '@/tables/orders'

export const Route = createFileRoute('/_authenticated/orders/drafts')({
  validateSearch: resourceSearchSchema,
  component: DraftOrdersPage,
})

function DraftOrdersPage() {
  const searchParams = Route.useSearch()
  const { token } = useAuth()

  return (
    <ResourceTable
      tableKey="orders"
      queryKey="draft-orders"
      queryFn={(params) => spreeClient.admin.orders.list(params, { token: token! })}
      searchParams={searchParams}
      defaultParams={{ incomplete: 1 }}
      title="Draft Orders"
      actions={
        <Button size="sm" className="h-[2.125rem]">
          <PlusIcon className="size-4" />
          New Order
        </Button>
      }
    />
  )
}
