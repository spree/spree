// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type DeliveryMethodRuleUpdateParams = {
  /** Defaults to true on create. */
  active?: boolean
  /** Values for the rule kind's preference schema. */
  preferences?: Record<string, unknown>
  /**
   * Products an association-backed rule (`excluded_products_rule`) applies to. An empty list clears
   * them.
   */
  product_ids?: string[]
}
