export const DEFAULT_SPREE_PORT = 3000
export const STOREFRONT_PORT = 3001
export const DASHBOARD_PORT = 5173
// Seller panel dev server; 5174 matches @spree/cli's own default.
export const SELLER_DASHBOARD_PORT = 5174

export const STOREFRONT_REPO = 'https://github.com/spree/storefront.git'

/**
 * pnpm pinned into the generated root package.json's `packageManager` field.
 * Drift from the storefront's own pin is tolerable: CI resolves pnpm from the
 * storefront's package.json, so this only steers corepack at the wrapper root.
 */
export const PNPM_VERSION = '10.33.4'
export const SERVER_REPO = 'https://github.com/spree/spree-starter.git'

declare const __SPREE_PACKAGES_RANGE__: string

/**
 * The range a new project declares for the packages that carry the Spree
 * version: the major of the Spree release this build ships with (`^6.0.0-0`),
 * which resolves to the newest release, the one the `latest` image runs.
 * `spree upgrade` then moves them with the server.
 */
export const SPREE_PACKAGES_RANGE: string = __SPREE_PACKAGES_RANGE__
