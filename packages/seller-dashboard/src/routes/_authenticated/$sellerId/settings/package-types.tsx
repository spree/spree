import { PackageTypesPage, packageTypesSearchSchema } from '@spree/dashboard-core'
import { createFileRoute } from '@tanstack/react-router'
import type { z } from 'zod/v4'

export const Route = createFileRoute('/_authenticated/$sellerId/settings/package-types')({
  validateSearch: packageTypesSearchSchema,
  component: PackageTypesRoute,
})

/**
 * The same page the operator's dashboard renders, against this seller's own
 * packaging — the Seller API scopes it, so nothing here has to.
 *
 * No owner column: the list is this seller's rows plus the marketplace's
 * shared packaging, and the read-only rows already say which is which.
 */
function PackageTypesRoute() {
  const search = Route.useSearch() as z.infer<typeof packageTypesSearchSchema>

  return <PackageTypesPage search={search} />
}
