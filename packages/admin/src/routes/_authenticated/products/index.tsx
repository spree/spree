import { createFileRoute } from '@tanstack/react-router'
import { Button } from '@/components/ui/button'
import { ResourceTable, resourceSearchSchema } from '@/components/resource-table'
import { spreeClient } from '@/client'
import { useAuth } from '@/hooks/use-auth'
import { PlusIcon } from 'lucide-react'
import '@/tables/products'

export const Route = createFileRoute('/_authenticated/products/')({
  validateSearch: resourceSearchSchema,
  component: ProductsPage,
})

function ProductsPage() {
  const searchParams = Route.useSearch()
  const { token } = useAuth()

  return (
    <ResourceTable
      tableKey="products"
      queryKey="products"
      queryFn={(params) =>
        spreeClient.admin.products.list(params, { token: token! })
      }
      searchParams={searchParams}
      actions={
        <Button size="sm" className="h-[2.125rem]">
          <PlusIcon className="size-4" />
          Add Product
        </Button>
      }
    />
  )
}
