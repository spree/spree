// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type RoleUpdateParams = {
  /** Unique role name, the machine identifier shown capitalized in the dashboard. */
  name?: string
  description?: string | null
  /**
   * Permission keys (`read_orders`, `write_products`, ...) from the permissions endpoint. You can
   * only grant keys you hold yourself.
   */
  permissions?: string[]
}
