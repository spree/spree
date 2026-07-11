const API_BASE_URL = import.meta.env.VITE_SPREE_API_URL || ''

/**
 * Resolve `urlOrPath` (a path or absolute URL) against the API base and
 * report whether it targets the trusted API origin. Origins are computed
 * lazily so importing this module never touches `window` (node test envs).
 */
function resolveApiUrl(urlOrPath: string): { url: string; sameOrigin: boolean } {
  const url = /^https?:\/\//.test(urlOrPath) ? urlOrPath : `${API_BASE_URL}${urlOrPath}`
  const apiOrigin = API_BASE_URL ? new URL(API_BASE_URL).origin : window.location.origin
  const sameOrigin = new URL(url, window.location.origin).origin === apiOrigin
  return { url, sameOrigin }
}

/**
 * Authed fetch → Blob URL download for JWT-protected endpoints — a top-level
 * navigation cannot carry the in-memory token. Only requests to the API
 * origin get the `Authorization` header and cookies, so the token can't leak
 * to a third-party host (e.g. a URL echoed back by the server). The filename
 * comes from `Content-Disposition` when present, else `fallbackName`.
 */
export async function downloadFromApi(
  token: string | null,
  urlOrPath: string,
  fallbackName: string,
): Promise<void> {
  const { url, sameOrigin } = resolveApiUrl(urlOrPath)
  const headers: Record<string, string> = {}
  if (sameOrigin && token) headers.Authorization = `Bearer ${token}`

  const response = await fetch(url, {
    headers,
    credentials: sameOrigin ? 'include' : 'omit',
  })
  if (!response.ok) throw new Error(`Download failed: ${response.status}`)

  const disposition = response.headers.get('Content-Disposition')
  const filename = disposition?.match(/filename="?([^";]+)"?/)?.[1] ?? fallbackName

  const blob = await response.blob()
  const objectUrl = URL.createObjectURL(blob)
  const anchor = document.createElement('a')
  anchor.href = objectUrl
  anchor.download = filename
  document.body.appendChild(anchor)
  anchor.click()
  anchor.remove()
  URL.revokeObjectURL(objectUrl)
}
