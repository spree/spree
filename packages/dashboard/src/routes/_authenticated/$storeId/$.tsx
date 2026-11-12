/**
 * Catch-all splat route. TanStack Router falls through to this when none of
 * the dashboard's first-party routes (`customers/`, `orders/`, `products/`,
 * etc.) match. We use it to dispatch to plugin-registered routes from
 * `@spree/dashboard-core`'s route registry — plugins call
 * `defineDashboardPlugin({ routes: [{ path: '/brands', component: ... }] })`
 * and we render the matched component here.
 *
 * Unmatched paths get a simple "Not Found" message rather than the dashboard's
 * full 404 page; once the dashboard grows a proper 404 view, this can render
 * that instead.
 */
import { createFileRoute } from '@tanstack/react-router'
import { PluginRoutePage } from '../../../components/spree/plugin-route-page'

export const Route = createFileRoute('/_authenticated/$storeId/$')({
  component: PluginRouteDispatcher,
})

function PluginRouteDispatcher() {
  const { storeId, _splat } = Route.useParams() as { storeId: string; _splat?: string }
  return <PluginRoutePage storeId={storeId} path={_splat ?? ''} />
}
