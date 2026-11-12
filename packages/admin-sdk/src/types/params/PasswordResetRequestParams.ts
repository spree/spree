// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type PasswordResetRequestParams = {
  email: string
  /**
   * The page the emailed reset link points at, with the reset token appended. Honored only on the
   * dashboard origin, for an account that is staff of the store; ignored otherwise.
   */
  redirect_url?: string
}
