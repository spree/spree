---
'@spree/admin-sdk': minor
---

Cookie-backed admin authentication. The refresh token now lives in an `HttpOnly` signed cookie scoped to `/api/v3/admin/auth` instead of being returned in JSON; the access token is the only thing the SPA holds in memory. This eliminates the most attractive XSS target on the admin SPA and adds a real server-side logout that destroys the refresh-token row.

CSRF protection is provided by the combination of the cookie's `SameSite` attribute and the existing `Spree::AllowedOrigin` allowlist enforced via `Rack::Cors` — no separate CSRF token is issued or required by the SDK.

**Note on bump type:** `@spree/admin-sdk` is on a 0.x version line (`next` dist-tag, Developer Preview). Per semver §4 and Changesets convention, breaking changes on 0.x packages bump the minor — moving to `major` would mean 1.0.0 and signal API stability we do not yet guarantee. The changes below are breaking; coordinated with the server-side change shipping in Spree 5.5.

**Breaking changes:**

- `AuthTokens` no longer contains `refresh_token`. The shape is `{ token, user }`.
- `client.auth.refresh()` takes no arguments — it reads the refresh-token cookie. Previously it required `{ refresh_token }` in the body.
- New `client.auth.logout()` — POSTs to `/api/v3/admin/auth/logout`, which destroys the refresh-token row server-side and clears the auth cookie. Idempotent.
- `createAdminClient()` now defaults to `credentials: 'include'` so cookies flow on cross-origin requests. Override via `createAdminClient({ credentials: 'omit' })` if needed.
- The `secretKey || jwtToken` constructor guard has been relaxed: a cookie-auth SPA may start with neither and bootstrap by calling `auth.refresh()` immediately. Server-to-server callers should still pass `secretKey`.

When using `baseUrl: ''` (e.g. with a Vite dev proxy), the SDK now resolves the relative path against `window.location.origin` so `new URL` doesn't throw.
