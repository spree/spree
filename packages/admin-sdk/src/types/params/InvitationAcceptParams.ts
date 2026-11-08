// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type InvitationAcceptParams = {
  /**
   * Creates the account when the invitee has none yet. An existing account confirms it is theirs
   * with it, unless the request is already signed in as that account.
   */
  password?: string
  password_confirmation?: string
  first_name?: string
  last_name?: string
}
