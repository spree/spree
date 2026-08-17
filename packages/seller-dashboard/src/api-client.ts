import { setApiClient } from '@spree/dashboard-core'
import type { SellerApiClient } from '@spree/seller-sdk'
import { createSellerClient } from '@spree/seller-sdk'

/**
 * Which seller the signed-in user is acting as.
 *
 * Kept out of React state because the client needs it on every request,
 * including ones fired before any component renders. The URL is the real
 * source of truth — the `$sellerId` route layout writes it here as it renders
 * — and this copy is only what the request headers read.
 */
const SELLER_STORAGE_KEY = 'spree.seller.id'

let client: SellerApiClient | null = null

/**
 * Builds the Seller API client and registers it with the shared framework.
 *
 * The host calls this once at boot, before rendering. `@spree/dashboard-core`
 * is the framework behind both panels, so it cannot own either client — the
 * operator's dashboard registers an Admin API client the same way.
 *
 * Leave `baseUrl` unset for relative URLs, so the Vite dev proxy (or a
 * static-host rewrite in production) keeps the panel same-origin with the API
 * — which is what lets the seller refresh cookie ride under `SameSite=Lax`
 * without HTTPS. Set it only for a genuinely cross-origin deployment.
 */
export function createSellerApiClient({
  baseUrl = '',
}: {
  baseUrl?: string
} = {}): SellerApiClient {
  client = createSellerClient({ baseUrl })

  const remembered = rememberedSeller()
  if (remembered) client.setSeller(remembered)

  setApiClient({
    auth: client.auth,
    setToken: (token: string) => sellerClient().setToken(token),
    onUnauthorized: (handler) => sellerClient().onUnauthorized(handler),
    // A stale seller header would ride into the next seller's first requests
    // and 403 them against a seller they may hold no role on.
    clearTenant: forgetSeller,
    fetchPermissions: async () => {
      const response = await sellerClient().me()

      // The seller API grants capability by key alone — there are no CanCanCan
      // rules to report, and an empty list is the correct answer rather than a
      // missing one.
      return { rules: [], keys: response.permission_keys ?? [] }
    },
  })

  return client
}

/**
 * The registered client.
 *
 * Throws rather than returning null: a panel rendering without one is
 * misconfigured, and every call would otherwise fail further away with a less
 * useful message.
 */
export function sellerClient(): SellerApiClient {
  if (!client) {
    throw new Error(
      '@spree/seller-dashboard: no API client created. Call createSellerApiClient() at boot, ' +
        'before rendering the panel.',
    )
  }

  return client
}

/** Points subsequent requests at a seller, without persisting the choice. */
export function setActiveSeller(sellerId: string): void {
  sellerClient().setSeller(sellerId)
}

/** Persists the choice so a reload does not drop the seller back to the picker. */
export function rememberSeller(sellerId: string): void {
  localStorage.setItem(SELLER_STORAGE_KEY, sellerId)
  setActiveSeller(sellerId)
}

export function forgetSeller(): void {
  localStorage.removeItem(SELLER_STORAGE_KEY)
  client?.setSeller('')
}

export function rememberedSeller(): string | null {
  return localStorage.getItem(SELLER_STORAGE_KEY)
}
