import {
  matchPluginRoute,
  outranksRouterMatch,
  usePermissions,
  usePluginRoutes,
} from '@spree/dashboard-core'
import { ErrorState } from '@spree/dashboard-ui'
import { CatchBoundary, type ErrorComponentProps, useRouterState } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import { SettingsContainer } from './settings-container'

const CATCH_ALL_ROUTE_ID = '/_authenticated/$storeId/$'

/**
 * Renders the registry route matching `path` (the URL after `/$storeId/`), or
 * a not-found or not-authorized state. Render errors stay inside the page — a
 * broken third-party page shouldn't take down the dashboard shell.
 */
export function PluginRoutePage({ storeId, path }: { storeId: string; path: string }) {
  return (
    <CatchBoundary getResetKey={() => path} errorComponent={PluginRouteError}>
      <MatchedPluginRoute storeId={storeId} path={path} />
    </CatchBoundary>
  )
}

function PluginRouteError({ error }: ErrorComponentProps) {
  const { t } = useTranslation()
  return (
    <ErrorState
      title={t('admin.errors.plugin_route_title', { defaultValue: 'This page failed to render' })}
      error={error}
    />
  )
}

function MatchedPluginRoute({ storeId, path }: { storeId: string; path: string }) {
  const routes = usePluginRoutes()
  const searchParams = useRouterState({ select: (s) => s.location.search }) as Record<
    string,
    unknown
  >
  const { t } = useTranslation()
  const { permissions } = usePermissions()

  const match = matchPluginRoute(path, routes)

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
  const page = <Component params={match.params} storeId={storeId} searchParams={searchParams} />
  // A plugin page under `/settings` renders outside the settings layout, and
  // the shell leaves settings pages to pad themselves.
  return isSettingsPath(path) ? <SettingsContainer>{page}</SettingsContainer> : page
}

/**
 * The URL (after `/$storeId/`) when a registry route outranks the file route
 * the router matched — `/sellers/shopify` over `/sellers/$sellerId` — and so
 * must render in its place; otherwise `null`.
 */
export function usePluginRouteClaim(storeId: string): string | null {
  const routes = usePluginRoutes()
  // The match's own pathname rather than the location's: during a navigation
  // the location already points at the next page while the matches are still
  // the current one's.
  const routeId = useRouterState({ select: (s) => s.matches.at(-1)?.routeId })
  const pathname = useRouterState({ select: (s) => s.matches.at(-1)?.pathname })

  if (!routeId || !pathname || routeId === CATCH_ALL_ROUTE_ID) return null
  const prefix = `/${storeId}/`
  if (!pathname.startsWith(prefix)) return null

  const path = pathname.slice(prefix.length)
  const match = matchPluginRoute(path, routes)
  const routerPath = routeId.split('/$storeId')[1] ?? ''
  return match && outranksRouterMatch(match.entry.path, routerPath) ? path : null
}

function isSettingsPath(path: string) {
  return path === 'settings' || path.startsWith('settings/')
}
