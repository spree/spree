/**
 * File route for the brands list — compiled into the host's route tree by
 * `spreeDashboardPlugin()` (this directory is declared via the package.json
 * marker: `"spree": { "dashboard": { "routes": "./src/routes" } }`).
 *
 * The path literal is the FINAL composed path: plugin routes mount under the
 * dashboard's `_authenticated/$storeId` layout. Committing the correct
 * literal matters — the route generator verifies it and would rewrite the
 * file otherwise.
 */
import { resourceSearchSchema } from '@spree/dashboard-core'
import { createFileRoute } from '@tanstack/react-router'
import { BrandsListPage } from '../pages/brands-list'

export const Route = createFileRoute('/_authenticated/$storeId/brands/')({
  validateSearch: resourceSearchSchema,
  component: BrandsRoute,
})

function BrandsRoute() {
  const searchParams = Route.useSearch()
  return <BrandsListPage searchParams={searchParams} />
}
