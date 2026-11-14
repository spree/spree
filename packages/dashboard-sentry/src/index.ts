/**
 * @spree/dashboard-sentry: Sentry error tracking for the admin dashboard and
 * the seller panel. The host calls `initDashboardSentry()` from its entry
 * module, before rendering. See README.md.
 */
import * as Sentry from '@sentry/react'
import { APP_ROOT_SLOT, defineDashboardPlugin } from '@spree/dashboard-core'
import {
  captureCaughtError,
  errorTrackingEnabled,
  panelFromPackages,
  withRedaction,
} from './error-tracking'
import { SentryUser } from './sentry-user'

export interface DashboardSentryOptions extends Sentry.BrowserOptions {
  /** Report from development builds too. Off by default. */
  enableInDevelopment?: boolean
}

let started = false

/**
 * Starts Sentry for the panel and connects it to the dashboard: errors the
 * panel's error screens catch, the signed-in user and a `panel` tag. Takes
 * any Sentry browser option; `environment` defaults to the Vite mode.
 * Single-use tokens are redacted after the host's own `beforeSend` and
 * `beforeBreadcrumb` run. Does nothing without a `dsn`, in development
 * builds unless `enableInDevelopment` is set, or when called a second time.
 *
 * @returns whether Sentry was started
 */
export function initDashboardSentry({
  enableInDevelopment,
  ...options
}: DashboardSentryOptions = {}): boolean {
  if (started) return false
  if (
    !errorTrackingEnabled({
      dsn: options.dsn,
      production: import.meta.env.PROD,
      enableInDevelopment,
    })
  ) {
    return false
  }
  started = true

  Sentry.init({
    environment: import.meta.env.MODE,
    ...options,
    ...withRedaction(options),
  })
  // Tags events raised while the app starts, before `app.root` mounts.
  const panel = panelFromPackages(
    typeof __SPREE_PACKAGES__ === 'undefined' ? undefined : __SPREE_PACKAGES__,
  )
  if (panel) Sentry.setTag('panel', panel)

  defineDashboardPlugin({
    errorReporters: { sentry: captureCaughtError },
    slots: {
      [APP_ROOT_SLOT]: [{ id: 'sentry-user', component: SentryUser as never }],
    },
  })
  return true
}
