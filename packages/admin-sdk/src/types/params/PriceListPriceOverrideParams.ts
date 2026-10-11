// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type PriceListPriceOverrideParams = {
  /**
   * Updates this price row. Without it, the row upserts on `(variant_id, currency, min_quantity)`.
   */
  id?: string
  variant_id?: string
  currency?: string
  /** The rung of the variant's ladder. Omit for the bottom rung. */
  min_quantity?: number
  amount?: string | null
  compare_at_amount?: string | null
}
