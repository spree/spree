// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type CatalogProductTermsParams = {
  /**
   * Quantity terms keyed by product: `{ minimum_order_quantity, order_multiple }`, each a whole
   * number or null. A product whose pair is both null has its terms cleared; a product not yet in
   * the assortment is added.
   */
  terms: Record<string, unknown>
}
