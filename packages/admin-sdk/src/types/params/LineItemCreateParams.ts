// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type LineItemCreateParams = {
  /**
   * Identities the record has in external systems, keyed by system: the same
   * `{ system: external_id }` map the Admin API renders, so what you read can be sent straight
   * back. Systems you do not name keep the reference they have. A list of `{ system, external_id }`
   * entries is accepted too.
   */
  external_references?: Record<string, unknown>
  variant_id: string
  /** Defaults to 1 when adding an item. */
  quantity?: number
  /**
   * Negotiated unit price. Stamps the line `price_source: 'manual'`, so quantity changes and
   * recalculation never re-price it; an explicit null reverts the line to catalog pricing. Omit to
   * leave pricing alone. Draft (incomplete) orders only.
   */
  price?: string | null
  options?: Record<string, unknown>
}
