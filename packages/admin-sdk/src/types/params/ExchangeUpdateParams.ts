// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type ExchangeUpdateParams = {
  /** Where the goods come back to. */
  stock_location_id?: string
  /** One of the store's return reasons. */
  reason_id?: string
  memo?: string
  metadata?: Record<string, unknown>
}
