const API_BASE_URL = import.meta.env.VITE_SPREE_API_URL || ''

/** Stands in for the bearer token so a copied command never carries the real one. */
export const CURL_TOKEN_PLACEHOLDER = '$SPREE_API_TOKEN'

function shellQuote(value: string): string {
  return `'${value.replace(/'/g, `'\\''`)}'`
}

/**
 * A `curl` command for a request to `path`, resolved against the API base the
 * client uses (the page's own origin when the API is proxied through it).
 */
export function buildCurlCommand(
  path: string,
  headers: Record<string, string> = {},
  { method = 'GET', body }: { method?: string; body?: unknown } = {},
): string {
  const base = API_BASE_URL || (typeof window === 'undefined' ? '' : window.location.origin)
  const url = /^https?:\/\//.test(path) ? path : `${base}${path}`
  const lines = [
    `curl ${method === 'GET' ? '' : `-X ${method} `}${shellQuote(url)}`,
    `  -H "Authorization: Bearer ${CURL_TOKEN_PLACEHOLDER}"`,
    ...Object.entries(headers).map(([name, value]) => `  -H ${shellQuote(`${name}: ${value}`)}`),
    ...(body === undefined ? [] : [`  -d ${shellQuote(JSON.stringify(body, null, 2))}`]),
  ]
  return lines.join(' \\\n')
}
