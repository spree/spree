import { StockLocationsPage, stockLocationsSearchSchema } from '@spree/dashboard-core'
import { createFileRoute } from '@tanstack/react-router'
import type { z } from 'zod/v4'

export const Route = createFileRoute('/_authenticated/$sellerId/settings/stock-locations')({
  validateSearch: stockLocationsSearchSchema,
  component: StockLocationsRoute,
})

/**
 * The same page the operator's dashboard renders, against this seller's own
 * locations — the Seller API scopes them, so nothing here has to.
 *
 * No stock-levels panel: editing on-hand counts reads the Admin API and links
 * to the operator's product pages. A seller's stock lives on their products,
 * which is where the panel will edit it.
 */
function StockLocationsRoute() {
  const search = Route.useSearch() as z.infer<typeof stockLocationsSearchSchema>

  return <StockLocationsPage search={search} />
}
