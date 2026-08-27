import { createFileRoute } from '@tanstack/react-router'
import { ProductPage } from '../../../../pages/product'

export const Route = createFileRoute('/_authenticated/$sellerId/products/$productId')({
  component: () => <ProductPage mode="edit" />,
})
