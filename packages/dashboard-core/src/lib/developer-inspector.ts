import type { RequestCompleteEvent } from '@spree/admin-sdk'

/**
 * The developer inspector's request log: the admin client's recent requests,
 * kept in memory for this tab only. Nothing is persisted or sent anywhere.
 * Always recording, so the request behind a bug is already there when an
 * admin opens the drawer; the cap keeps the memory a tab holds small.
 */

export const DEVELOPER_INSPECTOR_LIMIT = 50

const FILTERED = '[FILTERED]'
/** Credential headers: masked in the log, never copied into a curl command. */
export const SENSITIVE_HEADERS = new Set([
  'authorization',
  'x-spree-api-key',
  'x-spree-token',
  'cookie',
])
// Rails' own filter_parameters list, so whatever the server's logs hide is
// hidden here too.
const SENSITIVE_FIELD = /passw|token|secret|_key$|crypt|salt|certificate|otp|ssn|cvv|cvc/i

export interface DeveloperInspectorEntry {
  id: number
  method: string
  path: string
  query?: RequestCompleteEvent['query']
  url: string
  /** `null` when no response arrived (network error). */
  status: number | null
  durationMs: number
  requestId: string | null
  requestHeaders: Record<string, string>
  requestBody: unknown
  responseBody: unknown
  /** The API error code (`record_not_found`), or the network error's name. */
  errorCode?: string
  errorMessage?: string
}

export function isFailedEntry(entry: DeveloperInspectorEntry): boolean {
  return entry.status === null || entry.status >= 400
}

/** Deep-copies a body, replacing every `password`, `token` or `secret` field. */
export function redactBody(value: unknown): unknown {
  if (typeof FormData !== 'undefined' && value instanceof FormData) return '[FormData]'
  if (Array.isArray(value)) return value.map(redactBody)
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(([key, v]) => [
        key,
        SENSITIVE_FIELD.test(key) && v != null ? FILTERED : redactBody(v),
      ]),
    )
  }
  return value
}

// A password reset carries its token in the path, so a failed attempt would
// otherwise show it in the drawer and in a bug report's failed requests.
const TOKEN_IN_PATH = /(\/auth\/password_resets\/)[^/?#]+/

export function redactPath(path: string): string {
  return path.replace(TOKEN_IN_PATH, `$1${FILTERED}`)
}

function redactUrl(url: string): string {
  const path = redactPath(url)
  const start = path.indexOf('?')
  if (start === -1) return path
  const params = new URLSearchParams(path.slice(start + 1))
  const sensitive = [...new Set(params.keys())].filter((key) => SENSITIVE_FIELD.test(key))
  if (sensitive.length === 0) return path
  for (const key of sensitive) params.set(key, FILTERED)
  return `${path.slice(0, start)}?${params}`
}

export function redactHeaders(headers: Record<string, string>): Record<string, string> {
  return Object.fromEntries(
    Object.entries(headers).map(([name, value]) => [
      name,
      SENSITIVE_HEADERS.has(name.toLowerCase()) ? FILTERED : value,
    ]),
  )
}

let entries: DeveloperInspectorEntry[] = []
let nextId = 1
const listeners = new Set<() => void>()

function emit() {
  for (const listener of listeners) listener()
}

export function subscribeDeveloperInspector(listener: () => void): () => void {
  listeners.add(listener)
  return () => listeners.delete(listener)
}

export function getDeveloperInspectorEntries(): DeveloperInspectorEntry[] {
  return entries
}

export function clearDeveloperInspector(): void {
  entries = []
  emit()
}

/** The admin client's `onRequestComplete`. */
export function recordRequest(event: RequestCompleteEvent): void {
  const error = event.error as { code?: unknown; name?: unknown; message?: unknown } | undefined
  const entry: DeveloperInspectorEntry = {
    id: nextId++,
    method: event.method,
    path: redactUrl(event.path),
    query: redactBody(event.query) as RequestCompleteEvent['query'],
    url: redactUrl(event.url),
    status: event.status,
    durationMs: Math.round(event.durationMs),
    requestId: event.requestId,
    requestHeaders: redactHeaders(event.requestHeaders),
    requestBody: redactBody(event.requestBody),
    responseBody: redactBody(event.responseBody),
  }
  if (error) {
    entry.errorCode = String(error.code ?? error.name ?? 'error')
    if (typeof error.message === 'string') entry.errorMessage = error.message
  }

  entries = [entry, ...entries].slice(0, DEVELOPER_INSPECTOR_LIMIT)
  emit()
}
