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

// Strings anywhere inside `value`: console breadcrumbs keep each logged
// argument in `data.arguments`, and a rejected plain object lands in
// `extra.__serialized__`. An object's `toJSON` result is what Sentry sends,
// so that is what gets redacted.
function redactDeep(value: unknown, depth = 0): unknown {
  if (typeof value === 'string') return redactTokens(value)
  if (depth > 5 || value === null || typeof value !== 'object') return value
  if ('toJSON' in value && typeof value.toJSON === 'function') {
    return redactDeep(value.toJSON(), depth + 1)
  }
  if (Array.isArray(value)) return value.map((item) => redactDeep(item, depth + 1))
  return Object.fromEntries(
    Object.entries(value).map(([key, item]) => [key, redactDeep(item, depth + 1)]),
  )
}

// Sentry may have normalized a whole `data` or `extra` object to a string by
// the time an event is sent, so the result keeps whatever shape it came in.
function redactData<T>(data: T): T {
  return redactDeep(data) as T
}

// The page URL, its Referer header, the error's own text, its extra data and
// its breadcrumbs as Sentry normalized them.
export function scrubErrorEvent(event: Sentry.ErrorEvent) {
  if (event.request?.url) event.request.url = redactTokens(event.request.url)
  if (event.request?.headers) event.request.headers = redactData(event.request.headers)
  if (event.message) event.message = redactTokens(event.message)
  for (const exception of event.exception?.values ?? []) {
    if (exception.value) exception.value = redactTokens(exception.value)
  }
  if (event.extra) event.extra = redactData(event.extra)
  for (const breadcrumb of event.breadcrumbs ?? []) scrubBreadcrumb(breadcrumb)
  return event
}

// Navigation (from, to), fetch/XHR (url) and console (message) breadcrumbs.
export function scrubBreadcrumb(breadcrumb: Sentry.Breadcrumb) {
  if (breadcrumb.message) breadcrumb.message = redactTokens(breadcrumb.message)
  if (breadcrumb.data) breadcrumb.data = redactData(breadcrumb.data)
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
