// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type AdminUserUpdateParams = {
  first_name?: string
  last_name?: string
  /**
   * Role IDs of the current store the user should hold. Replaces the user's roles on this store; an
   * empty list removes them all.
   */
  role_ids?: string[]
}
