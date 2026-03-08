import { createFileRoute } from '@tanstack/react-router'

export const Route = createFileRoute('/_authenticated/orders/$orderId')({
  component: OrderDetailPage,
})

function OrderDetailPage() {
  const { orderId } = Route.useParams()

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-medium">Order {orderId}</h1>
      <p className="text-muted-foreground">Order detail page will be implemented here.</p>
    </div>
  )
}
