// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type DeliveryOriginGroupParams = {
  name?: string | null
  position?: number
  /**
   * Prefixed stock location IDs (`sloc_...`); replaces the full set. Empty means every store
   * location.
   */
  stock_location_ids?: string[]
}
