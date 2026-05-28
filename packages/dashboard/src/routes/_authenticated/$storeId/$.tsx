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
import { matchPluginRoute, usePermissions, usePluginRoutes } from '@spree/dashboard-core'
import { ErrorState } from '@spree/dashboard-ui'
import { createFileRoute } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'

export const Route = createFileRoute('/_authenticated/$storeId/$')({
  component: PluginRouteDispatcher,
})

function PluginRouteDispatcher() {
  const { storeId, _splat } = Route.useParams() as { storeId: string; _splat?: string }
  const searchParams = Route.useSearch() as Record<string, unknown>
  const routes = usePluginRoutes()
  const { t } = useTranslation()
  const { permissions } = usePermissions()

  const match = matchPluginRoute(_splat ?? '', routes)

  if (!match) {
    return (
      <ErrorState
        title={t('admin.errors.not_found_title', { defaultValue: 'Page not found' })}
        description={t('admin.errors.not_found_description', {
          defaultValue: 'The page you’re looking for doesn’t exist.',
        })}
      />
    )
  }

  if (match.entry.subject && !permissions.can('read', match.entry.subject)) {
    return (
      <ErrorState
        title={t('admin.errors.forbidden_title', { defaultValue: 'Not authorized' })}
        description={t('admin.errors.forbidden_description', {
          defaultValue: 'You don’t have permission to view this page.',
        })}
      />
    )
  }

  const Component = match.entry.component
  return <Component params={match.params} storeId={storeId} searchParams={searchParams} />
}
