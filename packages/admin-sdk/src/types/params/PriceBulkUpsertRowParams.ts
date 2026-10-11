// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type PriceBulkUpsertRowParams = {
  /**
   * Present: updates that row. Absent: upserts on
   * `(variant_id, currency, price_list_id, min_quantity)`.
   */
  id?: string | null
  variant_id: string
  currency: string
  /** Omit or null for a base price. */
  price_list_id?: string | null
  /**
   * The rung of the variant's ladder. Omit for the bottom rung; anything above 1 requires a
   * `price_list_id`. A variant carries at most ten rungs on one list per currency.
   */
  min_quantity?: number
  amount?: string | null
  compare_at_amount?: string | null
}
