// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type AllowedOriginUpdateParams = {
  /**
   * Origin to allow in admin CORS preflight checks: a bare `scheme://host[:port]` (no path, query
   * or fragment) using `http` or `https`.
   */
  origin?: string
}
