// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type ReturnUpdateParams = {
  /**
   * Identities the record has in external systems, keyed by system: the same
   * `{ system: external_id }` map the Admin API renders, so what you read can be sent straight
   * back. Systems you do not name keep the reference they have. A list of `{ system, external_id }`
   * entries is accepted too.
   */
  external_references?: Record<string, unknown>
  /** Where the goods come back to. Defaults to the location that shipped them. */
  stock_location_id?: string
  /** One of the store's return reasons. */
  reason_id?: string
  memo?: string
  metadata?: Record<string, unknown>
}
