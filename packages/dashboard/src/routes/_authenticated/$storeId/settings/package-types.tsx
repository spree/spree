import { PackageTypesPage, packageTypesSearchSchema } from '@spree/dashboard-core'
import { createFileRoute } from '@tanstack/react-router'
import type { z } from 'zod/v4'
// Adds the seller column to the shared table — operator-only, see the file.
import '../../../../tables/package-types'

export const Route = createFileRoute('/_authenticated/$storeId/settings/package-types')({
  validateSearch: packageTypesSearchSchema,
  component: PackageTypesRoute,
})

/**
 * The page itself lives in `@spree/dashboard-core` so the marketplace seller
 * panel renders the same one. What stays here is the route (paths differ per
 * panel, and file routes are generated per app) and the owner column, which
 * only the operator's list needs.
 */
function PackageTypesRoute() {
  // Cast: the inferred search type unions with the parent layout's shape,
  // which does not know about our `edit`/`new` keys. The runtime schema is
  // still the source of truth — this gets past the parent-union narrowing.
  const search = Route.useSearch() as z.infer<typeof packageTypesSearchSchema>

  return <PackageTypesPage search={search} />
}
