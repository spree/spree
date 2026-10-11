// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type StockLevelParams = {
  id?: string
  /** The location holding the stock (`sloc_...`). */
  stock_location_id: string
  /**
   * Units physically at the location, not units available to sell: stock promised to placed orders
   * counts until it ships. Sent as the count the shelf should end at; the API records the
   * difference as an adjustment in the stock history.
   */
  count_on_hand: number
  /** Whether this location sells the variant beyond what it holds. */
  backorderable?: boolean
}
