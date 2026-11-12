import { buildCurlCommand } from './curl'
import { type DeveloperInspectorEntry, SENSITIVE_HEADERS } from './developer-inspector'

const ADMIN_API_PREFIX = '/api/v3/admin'
// Credentials are replaced by the placeholder; a replayed idempotency key
// would return the cached response instead of running the request again.
const OMITTED_HEADERS = new Set([...SENSITIVE_HEADERS, 'idempotency-key'])

function isSendableBody(body: unknown): boolean {
  return body !== undefined && body !== null && typeof body !== 'string'
}

/** A curl command replaying the request, with a placeholder for the token. */
export function entryToCurl(entry: DeveloperInspectorEntry): string {
  const headers = Object.fromEntries(
    Object.entries(entry.requestHeaders).filter(
      ([name]) => !OMITTED_HEADERS.has(name.toLowerCase()),
    ),
  )
  return buildCurlCommand(entry.url, headers, {
    method: entry.method,
    body: isSendableBody(entry.requestBody) ? entry.requestBody : undefined,
  })
}

/**
 * The same request through `@spree/admin-sdk`. Uses the low-level
 * `adminClient.request`, which always matches the wire call; the resource
 * method names would be a guess.
 */
export function entryToSdkCall(entry: DeveloperInspectorEntry): string {
  const path = entry.path.startsWith(ADMIN_API_PREFIX)
    ? entry.path.slice(ADMIN_API_PREFIX.length)
    : entry.path
  const options: Record<string, unknown> = {}
  if (entry.query && Object.keys(entry.query).length > 0) options.params = entry.query
  if (isSendableBody(entry.requestBody)) options.body = entry.requestBody
  const args = [JSON.stringify(entry.method), JSON.stringify(path)]
  if (Object.keys(options).length > 0) args.push(JSON.stringify(options, null, 2))
  return `await adminClient.request(${args.join(', ')})`
}
