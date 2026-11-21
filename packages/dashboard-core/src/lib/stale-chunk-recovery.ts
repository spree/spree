/**
 * Recovery from a stale build.
 *
 * After a deploy, a tab opened before it still holds the previous
 * `index.html`, which names chunk hashes the new build no longer has. The
 * first time that tab loads a lazy component or route, the import fails
 * ("Failed to fetch dynamically imported module") and the page it was on
 * crashes into its error screen. A reload fetches the new `index.html` and
 * the new chunk names, so that is what recovery does.
 *
 * The time of the last reload is kept in session storage and honoured for a
 * minute: a chunk that is still missing after the reload means a broken
 * build, not a stale tab, and is left to the error screen (and reported)
 * instead of reloading in a loop. It is deliberately not cleared when a page
 * loads, because every reload loads the shell — clearing it there would
 * reinstate the loop. A second deploy later in the same open tab still
 * recovers once the minute is up.
 */

export const STALE_CHUNK_RELOADED_AT_KEY = 'spree:reloaded-for-chunk'
export const STALE_CHUNK_RELOAD_WINDOW_MS = 60_000

// What each engine says when a module script cannot be fetched or is not
// JavaScript (the SPA fallback answers a missing chunk with `index.html`),
// and what Vite's preload helper says for a missing stylesheet.
const STALE_CHUNK_MESSAGES = [
  'failed to fetch dynamically imported module', // Chromium
  'error loading dynamically imported module', // Firefox
  'importing a module script failed', // Safari
  'is not a valid javascript mime type', // a module answered with HTML
  'unable to preload css',
]

let reloading = false

/** Whether `error` is a failed load of a code-split chunk. */
export function isStaleChunkError(error: unknown): boolean {
  const message =
    error instanceof Error
      ? error.message
      : typeof error === 'object' && error !== null && 'message' in error
        ? String((error as { message: unknown }).message)
        : typeof error === 'string'
          ? error
          : ''
  const normalized = message.toLowerCase()
  if (STALE_CHUNK_MESSAGES.some((text) => normalized.includes(text))) return true
  // An error wrapping the failed import, such as a router's.
  const cause = error instanceof Error ? error.cause : undefined
  return cause !== undefined && cause !== error && isStaleChunkError(cause)
}

/** Whether a reload for a stale chunk is under way in this page. */
export function isReloadingForStaleChunk(): boolean {
  return reloading
}

function readReloadedAt(storage: Storage | undefined): number {
  try {
    return Number(storage?.getItem(STALE_CHUNK_RELOADED_AT_KEY) ?? 0) || 0
  } catch {
    return 0
  }
}

function sessionStorageOrUndefined(): Storage | undefined {
  try {
    return typeof sessionStorage === 'undefined' ? undefined : sessionStorage
  } catch {
    return undefined
  }
}

/**
 * Reloads the page to pick up the current build, unless this tab already
 * reloaded for a stale chunk within the last minute. Without session storage
 * (blocked site data) there is no way to tell a stale tab from a broken
 * build across the reload, so nothing is done.
 *
 * @returns whether a reload was started (or already is)
 */
export function reloadForStaleChunk({
  storage = sessionStorageOrUndefined(),
  reload = () => window.location.reload(),
  now = Date.now(),
}: {
  storage?: Storage
  reload?: () => void
  now?: number
} = {}): boolean {
  if (reloading) return true
  if (!storage) return false
  if (now - readReloadedAt(storage) < STALE_CHUNK_RELOAD_WINDOW_MS) return false
  try {
    storage.setItem(STALE_CHUNK_RELOADED_AT_KEY, String(now))
  } catch {
    return false
  }
  reloading = true
  reload()
  return true
}

let uninstall: (() => void) | undefined

/**
 * Listens for Vite's `vite:preloadError`, raised for every failed dynamic
 * import in a production build — lazy routes, `React.lazy` components and the
 * chunks they depend on — and reloads the page instead of letting the import
 * reject. A failure within a minute of the last reload is let through, so a
 * broken build reaches the error screen. Each panel's shell calls this once
 * on import; a second call does nothing.
 *
 * @returns a function that removes the listener
 */
export function installStaleChunkRecovery(target: EventTarget | undefined = globalThis.window) {
  if (uninstall) return uninstall
  if (!target) return () => {}
  const onPreloadError = (event: Event) => {
    if (reloadForStaleChunk()) event.preventDefault()
  }
  target.addEventListener('vite:preloadError', onPreloadError)
  uninstall = () => {
    target.removeEventListener('vite:preloadError', onPreloadError)
    uninstall = undefined
  }
  return uninstall
}

/** For tests: forget a reload started in this module. */
export function resetStaleChunkRecoveryForTests() {
  reloading = false
  uninstall?.()
}
