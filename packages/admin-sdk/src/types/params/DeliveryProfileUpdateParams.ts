// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type DeliveryProfileUpdateParams = {
  name?: string
  /**
   * Registered profile kind (`shipping`, `digital`, extension kinds) from the kinds endpoint. Read
   * on create only; defaults to shipping.
   */
  kind?: string
  /** Promotes this profile to the store default; the previous default is demoted. */
  default?: boolean
  position?: number
  /**
   * Prefixed stock location IDs (`sloc_...`); replaces the full set. Empty means every store
   * location.
   */
  stock_location_ids?: string[]
}
