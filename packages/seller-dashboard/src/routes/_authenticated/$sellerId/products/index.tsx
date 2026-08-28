import { type ResourceSearch, resourceSearchSchema } from '@spree/dashboard-core'
import { createFileRoute } from '@tanstack/react-router'
import { z } from 'zod'
import { ProductsPage } from '../../../../pages/products'

// `import` carries the prefixed id of the import whose wizard is open over the
// table — deep-linkable and refresh-safe, which is what lets the import-done
// email link straight back into it.
const productsSearchSchema = resourceSearchSchema.extend({
  import: z.string().optional(),
})

export const Route = createFileRoute('/_authenticated/$sellerId/products/')({
  validateSearch: productsSearchSchema,
  component: ProductsRoute,
})

function ProductsRoute() {
  // Cast: the inferred type unions with the parent layout's shape.
  const search = Route.useSearch() as ResourceSearch & { import?: string }

  return <ProductsPage search={search} />
}
