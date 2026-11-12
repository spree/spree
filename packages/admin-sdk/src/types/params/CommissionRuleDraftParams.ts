// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type CommissionRuleDraftParams = {
  /** Present for an existing rule; omit to create one. */
  id?: string | null
  /** A kind from `GET /commission_rates/rule_types`. */
  type: string
  /** Configuration for the kind, per its type's `schema`. */
  preferences?: Record<string, unknown>
  /** For kinds that name products, which are kept outside preferences. */
  product_ids?: string[]
}
