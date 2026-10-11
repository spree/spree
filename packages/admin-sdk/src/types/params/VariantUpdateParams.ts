// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { CountryCode } from '../generated'
import type { CurrencyCode } from '../generated'
import type { PriceParams } from './PriceParams'
import type { StockLevelParams } from './StockLevelParams'
import type { VariantOptionParams } from './VariantOptionParams'

export type VariantUpdateParams = {
  /**
   * Identities the record has in external systems, keyed by system: the same
   * `{ system: external_id }` map the Admin API renders, so what you read can be sent straight
   * back. Systems you do not name keep the reference they have. A list of `{ system, external_id }`
   * entries is accepted too.
   */
  external_references?: Record<string, unknown>
  sku?: string
  barcode?: string
  cost_price?: string | null
  cost_currency?: CurrencyCode
  weight?: number | null
  height?: number | null
  width?: number | null
  depth?: number | null
  weight_unit?: 'g' | 'kg' | 'lb' | 'oz'
  dimensions_unit?: 'mm' | 'cm' | 'in' | 'ft'
  hs_code?: string
  customs_description?: string
  country_of_origin?: CountryCode
  minimum_order_quantity?: number | null
  order_multiple?: number | null
  purchase_unit?: string
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
  seller_id?: string
  delivery_profile_id?: string | null
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
  tax_category_id?: string
  position?: number
  /** Per-currency prices. Upserted by currency. */
  prices?: PriceParams[]
  /** Stock per location. Upserted by location; omitted locations are removed. */
  stock_levels?: StockLevelParams[]
  /**
   * One pair per option type the variant takes part in (size, color). Option types and values are
   * created when missing. On update, omit to leave the option values untouched.
   */
  options?: VariantOptionParams[]
}
