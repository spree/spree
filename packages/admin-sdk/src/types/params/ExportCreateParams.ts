// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type ExportCreateParams = {
  /**
   * Which dataset to export, as its shorthand: `products`, `orders`, `customers`,
   * `product_translations`, `gift_cards`, `coupon_codes`, `newsletter_subscribers`,
   * `price_list_prices`, `purchase_orders`, or a type an extension registers.
   */
  type: string
  /**
   * `filtered` (the default) keeps `search_params`; `all` ignores them and exports every record in
   * scope.
   */
  record_selection?: 'filtered' | 'all'
  /**
   * Absolute URL of your admin exports view; the export-done email uses it as the download button
   * target. Only honored when it matches one of the store's allowed origins.
   */
  results_url?: string
  /**
   * A Ransack query, with the predicates the list endpoint accepts. A `price_list_prices` export
   * requires `price_list_id_eq` naming a price list of the current store, and refuses
   * `record_selection: "all"`.
   */
  search_params?: Record<string, unknown>
}
