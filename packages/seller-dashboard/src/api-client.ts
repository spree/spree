import { setApiClient } from '@spree/dashboard-core'
import type { SellerApiClient, SellerExportCreateParams } from '@spree/seller-sdk'
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

      // Both shapes, exactly as the operator's dashboard receives them. The
      // framework's `<Can>` reads CanCanCan rules; the key list is what the
      // API's own gate enforces. Dropping the rules here (an earlier version
      // did) left every `<Can>` on the panel answering false — silently.
      return { rules: response.permissions ?? [], keys: response.permission_keys ?? [] }
    },
    // The shared address form reads countries through the registered client,
    // so it works in a panel that has no admin credential.
    listCountries: () => sellerClient().countries.list(),
    createDirectUpload: (params) => sellerClient().directUploads.create(params),
    // A file download is a bare fetch, so it does not go through the client
    // and picks up none of its headers. Without the seller header the Seller
    // API refuses the request before the action runs, so an export would
    // generate fine and then fail to download.
    downloadHeaders: (): Record<string, string> => {
      const sellerId = rememberedSeller()

      return sellerId ? { 'X-Spree-Seller-Id': sellerId } : {}
    },
    // Backs the shared export dialog, the same one the operator's dashboard
    // renders. The Seller API narrows what may be exported to records that
    // can be scoped to one seller, and refuses anything else.
    exports: {
      create: (params) => sellerClient().exports.create(params as SellerExportCreateParams),
      get: (id) => sellerClient().exports.get(id),
    },
    // Backs the shared stock-locations page. No `delete`: a location holds
    // stock levels and is named on historical fulfillments, so the Seller API
    // does not offer it and the page hides the action accordingly.
    stockLocations: {
      list: (params) => sellerClient().stockLocations.list(params),
      get: (id) => sellerClient().stockLocations.get(id),
      create: (params) => sellerClient().stockLocations.create(params),
      update: (id, params) => sellerClient().stockLocations.update(id, params),
    },
    // No catalog reference data is registered: how a product is filed — its
    // type, categories, collections and tags — is the marketplace's own
    // merchandising, so the shared form's Categorization card has nothing to
    // read and hides (docs/plans/6.0-seller-product-submission.md).
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

/**
 * Persists the choice so a reload does not drop the seller back to the picker.
 *
 * Every access is guarded: a browser that blocks storage (sandboxed iframe,
 * blocked third-party storage, some private modes) throws on `localStorage`,
 * and these run at boot and during logout — the two places a throw would
 * leave the panel unusable rather than merely forgetful. Losing the memory is
 * a small cost; failing to boot or to sign out is not.
 */
export function rememberSeller(sellerId: string): void {
  try {
    localStorage.setItem(SELLER_STORAGE_KEY, sellerId)
  } catch {
    // Storage unavailable — the choice lives for this page only.
  }
  setActiveSeller(sellerId)
}

export function forgetSeller(): void {
  try {
    localStorage.removeItem(SELLER_STORAGE_KEY)
  } catch {
    // Nothing to forget; clearing the header below is what matters for logout.
  }
  client?.setSeller('')
}

export function rememberedSeller(): string | null {
  try {
    return localStorage.getItem(SELLER_STORAGE_KEY)
  } catch {
    return null
  }
}
