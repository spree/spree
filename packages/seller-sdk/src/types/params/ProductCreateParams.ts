// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { CurrencyCode } from '../generated'
import type { SellerProductMediaParams } from './SellerProductMediaParams'
import type { SellerProductVariantParams } from './SellerProductVariantParams'

export type ProductCreateParams = {
  name: string
  description?: string
  slug?: string
  meta_title?: string
  meta_description?: string
  meta_keywords?: string
  metadata?: Record<string, unknown>
  /**
   * The marketplace's product type this product is listed against, from the product types endpoint.
   * Null detaches it. Saving with a type seeds its option types onto the product.
   */
  product_type_id?: string | null
  /**
   * Which of the marketplace's delivery profiles the product ships under. A new product sent
   * without one lands on the profile marked default.
   */
  delivery_profile_id?: string
  /**
   * Shorthand for a simple (no-options) product: per-currency prices that forward to the product's
   * sole variant.
   */
  prices?: {
    /** Omit to price in the store's currency. A seller has no currency of their own. */
    currency?: CurrencyCode
    /**
     * A canonical decimal string (`"1234.56"`: period decimal, no grouping). The API does not parse
     * localized input.
     */
    amount: string
    compare_at_amount?: string | null
  }[]
  /**
   * The gallery, as a whole: a file absent from the list is removed. `signed_id` attaches a fresh
   * upload; `id` updates one already there.
   */
  media?: SellerProductMediaParams[]
  /**
   * The variants, as a whole: one absent from the list is removed. Pass `id` to update an existing
   * variant.
   */
  variants?: SellerProductVariantParams[]
}
