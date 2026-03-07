import { createFileRoute } from '@tanstack/react-router'

export const Route = createFileRoute('/_authenticated/products/$productId')({
  component: ProductDetailPage,
})

function ProductDetailPage() {
  const { productId } = Route.useParams()

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-medium">Product {productId}</h1>
      <p className="text-muted-foreground">Product detail page will be implemented here.</p>
    </div>
  )
}
