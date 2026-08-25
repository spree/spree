import { createFileRoute } from '@tanstack/react-router'
import { ProductPage } from '../../../../pages/product'

export const Route = createFileRoute('/_authenticated/$sellerId/products/new')({
  component: () => <ProductPage mode="new" />,
})
