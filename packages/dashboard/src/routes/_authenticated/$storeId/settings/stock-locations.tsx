import { StockLocationsPage, stockLocationsSearchSchema } from '@spree/dashboard-core'
import { createFileRoute } from '@tanstack/react-router'
import type { z } from 'zod/v4'
import { StockLevelsPanel } from '../../../../components/spree/stock-levels-panel'
// Adds the seller column to the shared table — operator-only, see the file.
import '../../../../tables/stock-locations'

export const Route = createFileRoute('/_authenticated/$storeId/settings/stock-locations')({
  validateSearch: stockLocationsSearchSchema,
  component: StockLocationsRoute,
})

/**
 * The page itself lives in `@spree/dashboard-core` so the marketplace seller
 * panel renders the same one. What stays here is the route (paths differ per
 * panel, and file routes are generated per app) and the on-hand stock editor,
 * which reads the Admin API and links to the operator's product pages.
 */
function StockLocationsRoute() {
  // Cast: the inferred search type unions with the parent layout's shape,
  // which does not know about our `edit`/`new` keys. The runtime schema is
  // still the source of truth — this gets past the parent-union narrowing.
  const search = Route.useSearch() as z.infer<typeof stockLocationsSearchSchema>

  return <StockLocationsPage search={search} stockLevelsPanel={StockLevelsPanel} />
}
