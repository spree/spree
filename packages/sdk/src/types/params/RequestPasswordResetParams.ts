// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type RequestPasswordResetParams = {
  /** The email of the account to reset. */
  email: string
  /**
   * Where the reset link sends the customer. Ignored unless it matches one of the store's allowed
   * origins.
   */
  redirect_url?: string
}
