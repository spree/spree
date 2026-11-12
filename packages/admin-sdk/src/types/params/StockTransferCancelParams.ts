// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type StockTransferCancelParams = {
  /**
   * Required once the units have left the source: either they come back (`restock`) or they are
   * written off as lost (`write_off`).
   */
  on_in_transit?: 'restock' | 'write_off'
  /** Recorded against the written-off lines. */
  reason?: string | null
}
