export const DEFAULT_SPREE_PORT = 3000
export const STOREFRONT_PORT = 3001
export const DASHBOARD_PORT = 5173

export const STOREFRONT_REPO = 'https://github.com/spree/storefront.git'

/**
 * pnpm pinned into the generated root package.json's `packageManager` field.
 * Drift from the storefront's own pin is tolerable: CI resolves pnpm from the
 * storefront's package.json, so this only steers corepack at the wrapper root.
 */
export const PNPM_VERSION = '10.33.4'
export const BACKEND_REPO = 'https://github.com/spree/spree-starter.git'

export const DEFAULT_ADMIN_EMAIL = 'spree@example.com'
export const DEFAULT_ADMIN_PASSWORD = 'spree123'
