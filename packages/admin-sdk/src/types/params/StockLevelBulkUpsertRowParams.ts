// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type StockLevelBulkUpsertRowParams = {
  variant_id: string
  stock_location_id: string
  /** The absolute level the external system reports. */
  count_on_hand?: number | null
  /**
   * A relative change, for feeds that report movements rather than levels. Each row needs
   * `count_on_hand` or `adjustment`.
   */
  adjustment?: number | null
  backorderable?: boolean | null
}
