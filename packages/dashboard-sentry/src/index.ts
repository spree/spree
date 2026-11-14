/**
 * @spree/dashboard-sentry — Sentry error tracking for the admin dashboard and
 * the seller panel. Installing the package activates it in either panel; it
 * stays off until VITE_SENTRY_DSN is set. See README.md.
 */
import { APP_ROOT_SLOT, defineDashboardPlugin } from '@spree/dashboard-core'
import {
  captureCaughtError,
  errorTrackingEnabled,
  initErrorTracking,
  panelFromPackages,
} from './error-tracking'
import { SentryUser } from './sentry-user'

const env = import.meta.env
const dsn = env.VITE_SENTRY_DSN

if (
  dsn &&
  errorTrackingEnabled({
    dsn,
    production: env.PROD,
    enableInDevelopment: env.VITE_SENTRY_ENABLE_IN_DEVELOPMENT,
  })
) {
  initErrorTracking({
    dsn,
    environment: env.VITE_SENTRY_ENVIRONMENT || env.MODE,
    release: env.VITE_SENTRY_RELEASE || undefined,
    panel: panelFromPackages(
      typeof __SPREE_PACKAGES__ === 'undefined' ? undefined : __SPREE_PACKAGES__,
    ),
  })

  defineDashboardPlugin({
    errorReporters: { sentry: captureCaughtError },
    slots: {
      [APP_ROOT_SLOT]: [{ id: 'sentry-user', component: SentryUser as never }],
    },
  })
}
