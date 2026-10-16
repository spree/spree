// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type CollectionRuleParams = {
  /** Omit to create a new rule. */
  id?: string
  /** Wire shorthand for the rule kind, from the collection rule types endpoint. */
  type?: string
  value?: string
  match_policy?: 'is_equal_to' | 'is_not_equal_to' | 'contains' | 'does_not_contain'
}
