// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type LineItemUpdateParams = {
  /** Defaults to 1 when adding an item. */
  quantity?: number
  /**
   * Negotiated unit price. Stamps the line `price_source: 'manual'`, so quantity changes and
   * recalculation never re-price it; an explicit null reverts the line to catalog pricing. Omit to
   * leave pricing alone. Draft (incomplete) orders only.
   */
  price?: string | null
  metadata?: Record<string, unknown>
}
