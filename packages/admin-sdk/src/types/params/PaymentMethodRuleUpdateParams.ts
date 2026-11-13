// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type PaymentMethodRuleUpdateParams = {
  /** Defaults to true on create. */
  active?: boolean
  /** Values for the rule kind's preference schema. */
  preferences?: Record<string, unknown>
}
