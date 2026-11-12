// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type StockLevelUpdateParams = {
  /**
   * Identities the record has in external systems, keyed by system: the same
   * `{ system: external_id }` map the Admin API renders, so what you read can be sent straight
   * back. Systems you do not name keep the reference they have. A list of `{ system, external_id }`
   * entries is accepted too.
   */
  external_references?: Record<string, unknown>
  /**
   * The count the shelf should end at: a whole number of zero or more. The API records the
   * difference as an `adjusted` movement, so the correction appears in the stock history.
   */
  count_on_hand?: number
  /**
   * A signed change to the shelf instead of a target count, applied to the count the API holds at
   * that moment and recorded the same way. Cannot be sent together with `count_on_hand`.
   */
  adjustment?: number
  /** Whether this location sells the variant beyond what it holds. */
  backorderable?: boolean
  /** Labels the correction in the stock history. Defaults to "Manual adjustment". */
  reason?: string
  metadata?: Record<string, unknown>
}
