// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { CountryCode } from '../generated'
import type { CurrencyCode } from '../generated'
import type { DimensionUnit } from '../generated'
import type { StockLevelParams } from './StockLevelParams'
import type { VariantOptionParams } from './VariantOptionParams'
import type { WeightUnit } from '../generated'

export type OfferCreateParams = {
  sku?: string
  barcode?: string
  cost_price?: string | null
  cost_currency?: CurrencyCode
  weight?: number | null
  height?: number | null
  width?: number | null
  depth?: number | null
  weight_unit?: WeightUnit | null
  dimensions_unit?: DimensionUnit | null
  hs_code?: string
  customs_description?: string
  country_of_origin?: CountryCode
  minimum_order_quantity?: number | null
  order_multiple?: number | null
  purchase_unit?: 'unit' | 'carton' | null
  units_per_carton?: number | null
  track_inventory?: boolean
  preorderable?: boolean
  preorder_ships_at?: string | null
  backorder_limit?: number | null
  /**
   * Which of the marketplace's delivery profiles this offer ships under. Blank ships it the way the
   * master product does.
   */
  delivery_profile_id?: string | null
  metadata?: Record<string, unknown>
  /**
   * One entry per option type the master product is sold by, each naming a value the product
   * already carries. A missing axis or an unknown value is refused. On update, omit to leave the
   * options untouched.
   */
  options?: VariantOptionParams[]
  /** Per-currency prices. Omit `currency` and the price is recorded in the store's. */
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
  /** Stock per location, at this seller's own locations only. */
  stock_levels?: StockLevelParams[]
}
