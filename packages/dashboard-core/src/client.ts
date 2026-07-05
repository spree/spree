import { createAdminClient } from '@spree/admin-sdk'

// `VITE_SPREE_API_URL` controls whether the SDK builds relative or absolute URLs.
// Three deployment topologies, one code path:
//
//   1. Dev (default, env unset)            — Vite dev proxy forwards `/api/*` to
//      Rails. Browser sees same-origin → no CORS, no preflight, the refresh-token
//      cookie rides under `SameSite=Lax` without HTTPS.
//
//   2. Prod single-origin (env unset)      — Static-host rewrite (Render/nginx/
//      Cloudflare Worker) forwards `/api/*` to Rails. Same code path as dev,
//      same security posture, no CORS config to maintain. This is the
//      recommended topology for self-hosters.
//
//   3. Prod cross-origin (env set)         — `VITE_SPREE_API_URL=https://api.shop.com`
//      makes the SDK emit absolute URLs. Backend then needs the origin in
//      `Spree::AllowedOrigin`; cookies switch to `SameSite=None; Secure`
//      (handled server-side by Rails.env). Use when the admin lives on a CDN
//      and you don't want an edge proxy.
const baseUrl = import.meta.env.VITE_SPREE_API_URL || ''

export const adminClient = createAdminClient({
  baseUrl,
  // No initial token — auth-provider bootstraps via /auth/refresh on mount.
})
