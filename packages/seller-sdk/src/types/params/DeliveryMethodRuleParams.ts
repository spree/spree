// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type DeliveryMethodRuleParams = {
  id?: string
  /** A type from `/delivery_methods/rule_types`. */
  type: string
  active?: boolean
  preferences?: Record<string, unknown>
}
