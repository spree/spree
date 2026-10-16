// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type SellerExportCreateParams = {
  /** Which dataset to export. */
  type: 'orders' | 'products'
  /** `filtered` (default) keeps `search_params`; `all` exports everything this seller owns. */
  record_selection?: 'filtered' | 'all'
  /**
   * Ransack predicates, the same shape the list endpoints take. Ignored when `record_selection` is
   * `all`.
   */
  search_params?: Record<string, unknown>
  /**
   * Panel URL the export-done email links back to. Honored only when it matches one of the store's
   * allowed origins.
   */
  results_url?: string
}
