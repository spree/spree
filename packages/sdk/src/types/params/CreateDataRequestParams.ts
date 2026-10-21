// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type CreateDataRequestParams = {
  /** Defaults to `access`. */
  kind?: 'access' | 'erasure'
  /** Required for `erasure`. */
  current_password?: string
  /**
   * The storefront page the confirmation link opens, with the token appended. Ignored unless it
   * matches one of the store's allowed origins.
   */
  redirect_url?: string
}
