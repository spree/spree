import { SettingsIndexPage } from '@spree/dashboard-core'
import { createFileRoute } from '@tanstack/react-router'

export const Route = createFileRoute('/_authenticated/$sellerId/settings/')({
  component: SettingsIndexRoute,
})

/**
 * The same landing page the operator's dashboard renders: a card grid of every
 * settings area this member can reach. On a narrow viewport the settings rail
 * is hidden, so this grid is the only way into the area — it must not redirect
 * to a specific page.
 */
function SettingsIndexRoute() {
  const { sellerId } = Route.useParams()

  return <SettingsIndexPage tenantId={sellerId} />
}
