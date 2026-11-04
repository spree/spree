// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type PaymentMethodRuleCreateParams = {
  /** A rule kind from the payment method rule types endpoint. */
  type: string
  /** Defaults to true on create. */
  active?: boolean
  /** Values for the rule kind's preference schema. */
  preferences?: Record<string, unknown>
}
