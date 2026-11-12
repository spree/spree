// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { PromotionActionCalculatorParams } from './PromotionActionCalculatorParams'
import type { PromotionActionLineItemParams } from './PromotionActionLineItemParams'

export type PromotionActionUpdateParams = {
  /** Values for the action kind's settings schema, from `GET /promotion_actions/types`. */
  preferences?: Record<string, unknown>
  /** For adjustment actions. */
  calculator?: PromotionActionCalculatorParams
  /**
   * For `create_line_items`: the variants to add and their quantities. Variants left out are
   * removed.
   */
  line_items?: PromotionActionLineItemParams[]
}
