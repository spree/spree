import * as Sentry from '@sentry/react'
import type { ErrorInfo } from 'react'
import { redactTokens } from './redact-tokens'

// Development builds stay quiet unless asked, like the server's
// SENTRY_REPORT_ON_DEVELOPMENT.
export function errorTrackingEnabled({
  dsn,
  production,
  enableInDevelopment,
}: {
  dsn?: string
  production: boolean
  enableInDevelopment?: boolean
}) {
  return Boolean(dsn) && (production || enableInDevelopment === true)
}

// Every string inside `value`, however deep: console breadcrumbs keep each
// logged argument in `data.arguments`, a rejected plain object lands in
// `extra.__serialized__`, and a host hook can add data anywhere. An object's
// `toJSON` result is what Sentry sends, so that is what gets redacted. A value
// already seen on the current path is a cycle, which Sentry drops too.
function redactDeep(value: unknown, ancestors = new WeakSet<object>()): unknown {
  if (typeof value === 'string') return redactTokens(value)
  if (value === null || typeof value !== 'object') return value
  if (ancestors.has(value)) return '[Circular]'
  ancestors.add(value)
  try {
    if ('toJSON' in value && typeof value.toJSON === 'function') {
      return redactDeep(value.toJSON(), ancestors)
    }
    if (Array.isArray(value)) return value.map((item) => redactDeep(item, ancestors))
    return Object.fromEntries(
      Object.entries(value).map(([key, item]) => [key, redactDeep(item, ancestors)]),
    )
  } finally {
    ancestors.delete(value)
  }
}

/**
 * Every field of the event: its URL and headers, messages, extra data,
 * contexts, tags and breadcrumbs, including anything a host `beforeSend`
 * added. Sentry's own processing metadata holds live SDK objects and is never
 * sent, so it is left alone. A field Sentry normalized to a string keeps that
 * shape.
 */
export function scrubErrorEvent(event: Sentry.ErrorEvent): Sentry.ErrorEvent {
  const { sdkProcessingMetadata, ...sent } = event
  return { ...(redactDeep(sent) as Sentry.ErrorEvent), sdkProcessingMetadata }
}

// Navigation (from, to), fetch/XHR (url) and console (message, arguments)
// breadcrumbs.
export function scrubBreadcrumb(breadcrumb: Sentry.Breadcrumb): Sentry.Breadcrumb {
  return redactDeep(breadcrumb) as Sentry.Breadcrumb
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
 * The host's own `beforeSend` and `beforeBreadcrumb`, followed by token
 * redaction, so nothing a host hook adds or keeps can carry a token out.
 */
export function withRedaction({
  beforeSend,
  beforeBreadcrumb,
}: Pick<Sentry.BrowserOptions, 'beforeSend' | 'beforeBreadcrumb'>): Pick<
  Sentry.BrowserOptions,
  'beforeSend' | 'beforeBreadcrumb'
> {
  return {
    beforeSend: async (event, hint) => {
      const kept = beforeSend ? await beforeSend(event, hint) : event
      return kept && scrubErrorEvent(kept)
    },
    beforeBreadcrumb: (breadcrumb, hint) => {
      const kept = beforeBreadcrumb ? beforeBreadcrumb(breadcrumb, hint) : breadcrumb
      return kept && scrubBreadcrumb(kept)
    },
  }
}

// Errors a panel's error screens caught, handed over through `errorReporters`.
export function captureCaughtError(error: unknown, errorInfo?: ErrorInfo) {
  const mechanism = { handled: true, type: 'auto.function.react.error_handler' }
  if (errorInfo) Sentry.captureReactException(error, errorInfo, { mechanism })
  else Sentry.captureException(error, { mechanism })
}
