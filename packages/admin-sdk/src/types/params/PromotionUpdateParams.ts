// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { PromotionActionDraftParams } from './PromotionActionDraftParams'
import type { PromotionRuleDraftParams } from './PromotionRuleDraftParams'

export type PromotionUpdateParams = {
  name?: string
  description?: string | null
  /** Required for single-code coupon promotions. Ignored when `multi_codes` is true. */
  code?: string | null
  path?: string | null
  starts_at?: string | null
  expires_at?: string | null
  usage_limit?: number | null
  match_policy?: 'all' | 'any'
  /** `coupon_code` needs a code (or `multi_codes`); `automatic` applies without one. */
  kind?: 'coupon_code' | 'automatic'
  /** Generates `number_of_codes` codes starting with `code_prefix`. */
  multi_codes?: boolean
  number_of_codes?: number | null
  code_prefix?: string | null
  promotion_category_id?: string | null
  /**
   * The rules the promotion should have: entries with `id` update, entries without are created, and
   * rules left out are removed.
   */
  rules?: PromotionRuleDraftParams[]
  /** The actions the promotion should have, matched the same way as `rules`. */
  actions?: PromotionActionDraftParams[]
}
