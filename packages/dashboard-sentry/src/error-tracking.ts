import * as Sentry from '@sentry/react'
import type { ErrorInfo } from 'react'
import { redactTokens } from './redact-tokens'

export interface ErrorTrackingEnv {
  dsn?: string
  production: boolean
  enableInDevelopment?: string
}

// Development builds stay quiet unless asked, like the server's
// SENTRY_REPORT_ON_DEVELOPMENT.
export function errorTrackingEnabled({ dsn, production, enableInDevelopment }: ErrorTrackingEnv) {
  return Boolean(dsn) && (production || enableInDevelopment === 'true')
}

function redactValues(values: Record<string, unknown> | undefined) {
  if (!values) return
  for (const [key, value] of Object.entries(values)) {
    if (typeof value === 'string') values[key] = redactTokens(value)
  }
}

// The page URL, its Referer header, and the error's own text.
export function scrubErrorEvent(event: Sentry.ErrorEvent) {
  if (event.request?.url) event.request.url = redactTokens(event.request.url)
  redactValues(event.request?.headers)
  if (event.message) event.message = redactTokens(event.message)
  for (const exception of event.exception?.values ?? []) {
    if (exception.value) exception.value = redactTokens(exception.value)
  }
  return event
}

// Navigation (from, to), fetch/XHR (url) and console (message) breadcrumbs.
export function scrubBreadcrumb(breadcrumb: Sentry.Breadcrumb) {
  if (breadcrumb.message) breadcrumb.message = redactTokens(breadcrumb.message)
  redactValues(breadcrumb.data)
  return breadcrumb
}

/**
 * The panel a build is for, from the Spree packages it bundles, so events
 * raised while the app starts — before `app.root` mounts — are tagged too.
 */
export function panelFromPackages(packages: Record<string, string> | undefined) {
  if (packages?.['@spree/dashboard']) return 'admin'
  if (packages?.['@spree/seller-dashboard']) return 'seller'
}

/**
 * Starts Sentry. Its global handlers capture errors outside React (event
 * handlers, promise rejections) and render errors no error screen catches.
 */
export function initErrorTracking({
  panel,
  ...options
}: {
  dsn: string
  environment: string
  release?: string
  panel?: string
}) {
  Sentry.init({
    ...options,
    initialScope: panel ? { tags: { panel } } : undefined,
    beforeSend: scrubErrorEvent,
    beforeBreadcrumb: scrubBreadcrumb,
  })
}

// Errors a panel's error screens caught, handed over through `errorReporters`.
export function captureCaughtError(error: unknown, errorInfo?: ErrorInfo) {
  const mechanism = { handled: true, type: 'auto.function.react.error_handler' }
  if (errorInfo) Sentry.captureReactException(error, errorInfo, { mechanism })
  else Sentry.captureException(error, { mechanism })
}
