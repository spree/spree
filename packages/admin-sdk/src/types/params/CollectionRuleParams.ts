// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { CurrencyCode } from '../generated'

export type CollectionRuleParams = {
  /** Omit to create a new rule. */
  id?: string
  /** Wire shorthand for the rule kind, from the collection rule types endpoint. */
  type?: string
  /**
   * What the rule compares against. Rule types that name a record (category, product type, seller)
   * take its prefixed id.
   */
  value?: string
  /**
   * The relation. Each rule type accepts the `match_policies` the rule types endpoint lists for it.
   */
  match_policy?: 'is_equal_to' | 'is_not_equal_to' | 'contains' | 'does_not_contain' | 'greater_than' | 'less_than' | 'starts_with' | 'ends_with'
  /**
   * For `price` and `sale` rules: the currency they evaluate in. Null means the default currency of
   * the store.
   */
  currency?: CurrencyCode | null
  /** Values for the settings schema of the rule type, from the rule types endpoint. */
  preferences?: Record<string, unknown>
}
