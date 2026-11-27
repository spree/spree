// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type PaymentMethodRuleCreateParams = {
  /** A rule kind from the payment method rule types endpoint. */
  type: string
  /** Values for the rule kind's preference schema. */
  preferences?: Record<string, unknown>
}
