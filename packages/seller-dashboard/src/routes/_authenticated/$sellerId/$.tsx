/**
 * Catch-all splat route. TanStack Router falls through to this when none of
 * the panel's own routes match, and it renders whichever page a plugin
 * registered with `defineDashboardPlugin({ routes })` for the path — the same
 * dispatcher the operator's dashboard mounts under `$storeId`.
 */
import { matchPluginRoute, usePermissions, usePluginRoutes } from '@spree/dashboard-core'
import { ErrorState } from '@spree/dashboard-ui'
import { createFileRoute } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'

export const Route = createFileRoute('/_authenticated/$sellerId/$')({
  component: PluginRouteDispatcher,
  // A broken plugin page must not take down the panel around it.
  errorComponent: PluginRouteError,
})

function PluginRouteError({ error }: { error: Error }) {
  const { t } = useTranslation()
  return <ErrorState title={t('errors.page_failed_title')} description={error.message} />
}

function PluginRouteDispatcher() {
  const { sellerId, _splat } = Route.useParams() as { sellerId: string; _splat?: string }
  const searchParams = Route.useSearch() as Record<string, unknown>
  const routes = usePluginRoutes()
  const { t } = useTranslation()
  const { permissions } = usePermissions()

  const match = matchPluginRoute(_splat ?? '', routes)

  if (!match) {
    return (
      <ErrorState
        title={t('errors.not_found_title')}
        description={t('errors.not_found_description')}
      />
    )
  }

  if (match.entry.subject && !permissions.can('read', match.entry.subject)) {
    return (
      <ErrorState
        title={t('errors.forbidden_title')}
        description={t('errors.forbidden_description')}
      />
    )
  }

  const Component = match.entry.component
  // The registry's contract names the tenant `storeId`; in this panel the
  // tenant every page is scoped to is the seller.
  return <Component params={match.params} storeId={sellerId} searchParams={searchParams} />
}
