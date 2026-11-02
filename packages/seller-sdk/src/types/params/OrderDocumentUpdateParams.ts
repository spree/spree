// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type OrderDocumentUpdateParams = {
  label?: string
  /**
   * Whether the buyer sees it on their order. Off unless set; the buyer's own uploads are always
   * visible to them.
   */
  customer_visible?: boolean
  metadata?: Record<string, unknown>
}
