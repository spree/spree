// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type PriceListRuleParams = {
  /** Present for existing rules. Omit to create a new one. */
  id?: string | null
  /** Wire shorthand for the rule kind, from the price rule types endpoint. */
  type: string
  /** The rule kind's settings, keyed by preference name. */
  preferences?: Record<string, unknown>
}
