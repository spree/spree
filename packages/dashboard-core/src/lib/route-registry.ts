import type { ComponentType } from 'react'
import { useSyncExternalStore } from 'react'
import type { SubjectName } from './permissions'

/**
 * Dashboard route contributed by a plugin. Mounted under the dashboard's
 * `/_authenticated/$storeId/_plugins/$` catch-all, which reads this registry
 * at render time and dispatches based on the splat path.
 *
 * Path patterns use TanStack-Router-style param tokens (`$brandId`) inside the
 * plugin's namespace. The dashboard strips the `/$storeId/` prefix before
 * matching, so a plugin pattern of `/brands/$brandId` matches the URL
 * `/store_xyz/brands/br_abc123` with `params: { brandId: 'br_abc123' }`.
 */
export interface RouteEntry {
  /**
   * Stable identifier — used for register/remove/update and as the React key.
   * Mirrors the slug a plugin would use in its `nav.add({ key })` call so the
   * sidebar entry and route stay paired.
   */
  key: string
  /**
   * Path pattern relative to `/$storeId`. Examples: `/brands`,
   * `/brands/$brandId`, `/wishlists/$wishlistId/items`.
   * Must start with `/`. Do NOT include the `/$storeId` prefix; the dashboard
   * adds it at render time.
   */
  path: string
  /**
   * The component to render. Receives:
   * - `params`: extracted path params (e.g. matching `/brands/$brandId`
   *   against `/brands/br_abc` yields `{ brandId: 'br_abc' }`)
   * - `storeId`: the current store — every plugin route is implicitly scoped
   *   under `/$storeId/...`
   * - `searchParams`: the URL search-state object from TanStack Router. Use
   *   this with `<ResourceTable searchParams={searchParams} ... />` so
   *   filter/sort/pagination round-trip through the URL.
   */
  component: ComponentType<{
    params: Record<string, string>
    storeId: string
    searchParams: Record<string, unknown>
  }>
  /**
   * Optional CanCanCan subject required to view the route. The catch-all
   * renderer checks `permissions.can('read', subject)` and renders a 403
   * fallback when denied. Omit for routes that don't need permission gating.
   */
  subject?: SubjectName
}

const entries: RouteEntry[] = []
const listeners = new Set<() => void>()

function notify() {
  for (const l of listeners) l()
}

function subscribe(listener: () => void): () => void {
  listeners.add(listener)
  return () => {
    listeners.delete(listener)
  }
}

function getSnapshot(): readonly RouteEntry[] {
  return entries
}

interface RouteMutator {
  /** Register a route. Throws if `key` is already registered. */
  add(entry: RouteEntry): void
  /** Remove a route by key. No-op when missing. */
  remove(key: string): void
}

export const pluginRoutes: RouteMutator = {
  add(entry) {
    if (entries.some((e) => e.key === entry.key)) {
      throw new Error(`Plugin route "${entry.key}" already registered.`)
    }
    if (!entry.path.startsWith('/')) {
      throw new Error(`Plugin route "${entry.key}" path must start with "/", got "${entry.path}".`)
    }
    entries.push(entry)
    notify()
  },
  remove(key) {
    const i = entries.findIndex((e) => e.key === key)
    if (i === -1) return
    entries.splice(i, 1)
    notify()
  },
}

/**
 * Subscribe to plugin route updates. Returns the full list of registered
 * routes; the catch-all renderer matches against this on every navigation.
 */
export function usePluginRoutes(): readonly RouteEntry[] {
  return useSyncExternalStore(subscribe, getSnapshot, getSnapshot)
}

/**
 * Match a URL splat (the bit after `/$storeId/`) against the registered
 * routes. Returns the matched entry plus the extracted path params, or
 * `null` if nothing matched.
 *
 * Path patterns support TanStack-style `$param` tokens. A pattern segment
 * of `$brandId` matches any non-empty URL segment and binds it to
 * `params.brandId`.
 */
export function matchPluginRoute(
  splat: string,
  routes: readonly RouteEntry[],
): { entry: RouteEntry; params: Record<string, string> } | null {
  // Normalize: strip leading slash, drop empty trailing segments.
  const urlSegments = splat.replace(/^\/+/, '').split('/').filter(Boolean)
  for (const entry of routes) {
    const patternSegments = entry.path.replace(/^\/+/, '').split('/').filter(Boolean)
    if (patternSegments.length !== urlSegments.length) continue

    const params: Record<string, string> = {}
    let matched = true
    for (let i = 0; i < patternSegments.length; i++) {
      const p = patternSegments[i]
      const u = urlSegments[i]
      if (p.startsWith('$')) {
        params[p.slice(1)] = u
      } else if (p !== u) {
        matched = false
        break
      }
    }
    if (matched) return { entry, params }
  }
  return null
}

/** Test-only: clear the registry. */
export function __resetPluginRoutes(): void {
  entries.length = 0
  notify()
}
