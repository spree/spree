// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { CatalogAssignmentParams } from './CatalogAssignmentParams'
import type { CatalogOrderMinimumParams } from './CatalogOrderMinimumParams'
import type { CatalogPriceListParams } from './CatalogPriceListParams'

export type CatalogUpdateParams = {
  name?: string
  /** Internal note on what the agreement is, never shown to shoppers. */
  description?: string | null
  active?: boolean
  position?: number
  /**
   * The catalog-wide quantity terms, between a variant's own rule and a per-variant override. Null
   * leaves the field to the variant's own rule.
   */
  minimum_order_quantity?: number | null
  /**
   * The catalog-wide quantity terms, between a variant's own rule and a per-variant override. Null
   * leaves the field to the variant's own rule.
   */
  order_multiple?: number | null
  metadata?: Record<string, unknown>
  /**
   * The whole audience. An entry left out is withdrawn; omitting the key leaves the audience alone.
   */
  assignments?: CatalogAssignmentParams[]
  /**
   * The whole order-minimum set. A currency left out has its minimum lifted; omitting the key
   * leaves them alone.
   */
  order_minimums?: CatalogOrderMinimumParams[]
  /**
   * The price list this catalog prices through, written inline: an object creates the owned list or
   * updates it. Null deletes the list (a soft delete). Omit the key, or send `{}`, to leave the
   * pricing alone. A catalog with an empty assortment prices without hiding anything; curate or
   * import products to make it restrictive.
   */
  price_list?: CatalogPriceListParams | null
}
