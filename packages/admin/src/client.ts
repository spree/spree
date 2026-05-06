import { createAdminClient } from '@spree/admin-sdk'

// In dev, the Vite proxy forwards /api/* to the Rails server (same-origin to the browser).
// In prod, VITE_SPREE_API_URL points at the absolute API URL (cross-origin → cookies need
// SameSite=None; Secure, which the backend handles based on Rails.env).
// Empty baseUrl → relative URLs → uses the proxy in dev, absolute origin in prod builds
// only if the env var is set; when set, the SDK prepends it.
const baseUrl = import.meta.env.VITE_SPREE_API_URL || ''

export const adminClient = createAdminClient({
  baseUrl,
  // No initial token — auth-provider bootstraps via /auth/refresh on mount.
})
