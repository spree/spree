// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { PriceAdjustmentTierParams } from './PriceAdjustmentTierParams'
import type { PriceListPriceOverrideParams } from './PriceListPriceOverrideParams'
import type { PriceListRuleParams } from './PriceListRuleParams'

export type CatalogPriceListParams = {
  name?: string
  description?: string | null
  status?: string
  match_policy?: string
  starts_at?: string | null
  ends_at?: string | null
  /** Signed: negative discounts off base prices, positive marks up. */
  price_adjustment_percentage?: string | null
  adjust_compare_at?: boolean
  /**
   * Contextual rules, in practice a `volume_rule`. Audience rules are left as they are, and an
   * empty list clears the contextual rules.
   */
  rules?: PriceListRuleParams[]
  /**
   * Explicit per-variant amounts. An empty list clears them, which is what switching to a
   * percentage sends.
   */
  prices?: PriceListPriceOverrideParams[]
  /**
   * Quantity bands on the percentage. The payload is the whole ladder, so an empty list clears it.
   */
  price_adjustment_tiers?: PriceAdjustmentTierParams[]
}
