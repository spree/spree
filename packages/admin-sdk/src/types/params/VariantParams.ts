// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { CountryCode } from '../generated'
import type { CurrencyCode } from '../generated'
import type { DimensionUnit } from '../generated'
import type { PriceParams } from './PriceParams'
import type { StockLevelParams } from './StockLevelParams'
import type { VariantOptionParams } from './VariantOptionParams'
import type { WeightUnit } from '../generated'

export type VariantParams = {
  sku?: string
  barcode?: string
  cost_price?: string | null
  cost_currency?: CurrencyCode
  weight?: number | null
  height?: number | null
  width?: number | null
  depth?: number | null
  /** Null falls back to the store's weight unit. */
  weight_unit?: WeightUnit | null
  /** Null falls back to the store's unit system. */
  dimensions_unit?: DimensionUnit | null
  hs_code?: string
  customs_description?: string
  country_of_origin?: CountryCode
  minimum_order_quantity?: number | null
  order_multiple?: number | null
  purchase_unit?: 'unit' | 'carton' | null
  /** How many units fill one carton. */
  units_per_carton?: number | null
  /**
   * The carton this variant is packed into: a package type of kind `carton`. Its dimensions are
   * shared by every product packed the same way, so a corrected carton size fixes all of them at
   * once.
   */
  carton_package_type_id?: string | null
  /** What one packed carton weighs, in the variant's weight unit. */
  carton_weight?: number | null
  /** How many cartons stack on one pallet. */
  cartons_per_pallet?: number | null
  track_inventory?: boolean
  /**
   * Sell this variant before it's in stock. Adds the pre-order label and ships-by promise; the cap
   * comes from `backorder_limit`, an incoming stock count, or backorder.
   */
  preorderable?: boolean
  /**
   * The "ships by" date shown to customers while the variant is a pre-order. Once it passes, the
   * variant is no longer a pre-order. Null clears it.
   */
  preorder_ships_at?: string | null
  /**
   * Maximum units sellable beyond available stock, capping backorders and pre-orders. Null is
   * unlimited.
   */
  backorder_limit?: number | null
  position?: number
  /**
   * One pair per option type the variant takes part in (size, color). Option types and values are
   * created when missing.
   */
  options?: VariantOptionParams[]
  seller_id?: string
  delivery_profile_id?: string | null
  tax_category_id?: string
  /** Per-currency prices. Upserted by currency. */
  prices?: PriceParams[]
  /** Stock per location. Upserted by location; omitted locations are removed. */
  stock_levels?: StockLevelParams[]
}
