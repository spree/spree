import { createFileRoute } from '@tanstack/react-router'
import { OrderPage } from '../../../../pages/order'

export const Route = createFileRoute('/_authenticated/$sellerId/orders/$orderId')({
  component: OrderPage,
})
