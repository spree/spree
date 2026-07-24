import type { Store } from '@spree/admin-sdk'

/**
 * Resolves the storefront URL to link to from admin "View store" affordances,
 * or `null` when no storefront URL is configured.
 *
 * The serialized `store.url` always resolves — the backend falls back to the
 * store's formatted URL — so gate on the explicit `preferred_storefront_url`
 * preference: only return a link once a real storefront has been set.
 *
 * @param store the current store, or null/undefined while it loads
 * @returns an absolute URL, or null when the store has no configured storefront
 */
export function storefrontHref(store: Store | null | undefined): string | null {
  if (!store?.preferred_storefront_url) return null

  // Best-effort: prefix with https if the URL is just a hostname.
  return /^https?:\/\//.test(store.url) ? store.url : `https://${store.url}`
}
