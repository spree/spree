// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type ImportCreateParams = {
  /**
   * Which dataset to import, as its shorthand: `products`, `customers`, `product_translations`,
   * `price_list_prices`, `purchase_orders`, or a type an extension registers.
   */
  type: string
  /** The `signed_id` of the uploaded CSV, from `files.upload()` with `visibility: "private"`. */
  attachment_signed_id: string
  /** CSV column separator. Defaults to a comma. */
  delimiter?: ',' | ';' | '|' | '	'
  /**
   * Absolute URL of your admin imports view; the import-done email links back to it with
   * `?import=<id>` appended. Only honored when it matches one of the store's allowed origins.
   */
  results_url?: string
  /**
   * For `price_list_prices` imports: the price list the rows are merged into. Must belong to the
   * current store; other types ignore it.
   */
  price_list_id?: string
}
