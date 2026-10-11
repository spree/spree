// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type OrderRoutingRuleUpdateParams = {
  active?: boolean
  /**
   * 1-based priority in the channel's rule list. Omitted on create, the rule goes last; a new
   * position reorders the rest of the list around it.
   */
  position?: number
  /** Values for the rule kind's preference schema. */
  preferences?: Record<string, unknown>
}
