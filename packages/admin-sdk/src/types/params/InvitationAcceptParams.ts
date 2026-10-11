// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type InvitationAcceptParams = {
  /**
   * Required when the invitee has no account yet: it creates one. An existing account signs in
   * without it.
   */
  password?: string
  password_confirmation?: string
  first_name?: string
  last_name?: string
}
