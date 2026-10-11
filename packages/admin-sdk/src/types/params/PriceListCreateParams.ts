// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { PriceAdjustmentTierParams } from './PriceAdjustmentTierParams'
import type { PriceListPriceOverrideParams } from './PriceListPriceOverrideParams'
import type { PriceListRuleParams } from './PriceListRuleParams'

export type PriceListCreateParams = {
  name: string
  description?: string | null
  position?: number
  /**
   * Pair with `ends_at` to schedule the list: activating a list whose start is in the future marks
   * it `scheduled`.
   */
  starts_at?: string | null
  ends_at?: string | null
  /** `all`: every rule must match. `any`: one matching rule is enough. */
  match_policy?: 'all' | 'any'
  /** Signed: negative discounts off base prices, positive marks up. */
  price_adjustment_percentage?: string | null
  adjust_compare_at?: boolean
  /**
   * The complete rule set: rules are matched by `id` and updated, new ones are built, and rules
   * left out are removed.
   */
  rules?: PriceListRuleParams[]
  /**
   * Quantity bands on the list's percentage. The payload is the whole ladder: a band left out is
   * removed.
   */
  price_adjustment_tiers?: PriceAdjustmentTierParams[]
  /**
   * Per-variant price overrides. Each row upserts, so the variants it names become part of the
   * list. Curating whole products goes through the nested products endpoint instead.
   */
  prices?: PriceListPriceOverrideParams[]
}
