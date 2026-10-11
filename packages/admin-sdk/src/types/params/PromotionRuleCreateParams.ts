// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type PromotionRuleCreateParams = {
  /** The rule kind, from `GET /promotion_rules/types`. */
  type: string
  /** Values for the rule kind's settings schema, from `GET /promotion_rules/types`. */
  preferences?: Record<string, unknown>
  /** For the `product` rule. */
  product_ids?: string[]
  /** For the `category` rule. */
  category_ids?: string[]
  /** For the `user` rule: the customers who qualify. */
  customer_ids?: string[]
}
