import { createFileRoute } from '@tanstack/react-router'

export const Route = createFileRoute('/_authenticated/products/')({
  component: ProductsPage,
})

function ProductsPage() {
  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Products</h1>
      </div>
      <p className="text-muted-foreground">
        Product listing will be implemented here.
      </p>
    </div>
  )
}
