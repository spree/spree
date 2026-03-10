import { createFileRoute } from '@tanstack/react-router'
import { PlusIcon } from 'lucide-react'
import { adminClient } from '@/client'
import { ResourceTable, resourceSearchSchema } from '@/components/resource-table'
import { Button } from '@/components/ui/button'
import '@/tables/products'

export const Route = createFileRoute('/_authenticated/$storeId/products/')({
  validateSearch: resourceSearchSchema,
  component: ProductsPage,
})

function ProductsPage() {
  const searchParams = Route.useSearch()

  return (
    <ResourceTable
      tableKey="products"
      queryKey="products"
      queryFn={(params) => adminClient.products.list(params)}
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
