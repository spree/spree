import { SettingsIndexPage } from '@spree/dashboard-core'
import { createFileRoute } from '@tanstack/react-router'

export const Route = createFileRoute('/_authenticated/$storeId/settings/')({
  component: SettingsIndexRoute,
})

/**
 * The page itself lives in `@spree/dashboard-core` so the marketplace seller
 * panel renders the same one. What stays here is the route — paths differ per
 * panel, and file routes are generated per app.
 */
function SettingsIndexRoute() {
  const { storeId } = Route.useParams()

  return <SettingsIndexPage tenantId={storeId} />
}
