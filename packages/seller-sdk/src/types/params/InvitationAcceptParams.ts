// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type InvitationAcceptParams = {
  /** Sets the password of a new account, or confirms the password of an existing one. */
  password?: string
  password_confirmation?: string
  /** Used only when the invitation creates a new account. */
  first_name?: string
  /** Used only when the invitation creates a new account. */
  last_name?: string
}
