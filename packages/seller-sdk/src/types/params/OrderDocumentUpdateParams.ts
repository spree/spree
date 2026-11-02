// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type OrderDocumentUpdateParams = {
  label?: string
  /**
   * Whether the buyer sees it on their order. Off unless set; the buyer's own uploads are always
   * visible to them.
   */
  customer_visible?: boolean
  /**
   * A `signed_id` from `files.upload()` with `visibility: 'private'`. PDF, image, office document
   * or CSV.
   */
  file_signed_id?: string
  metadata?: Record<string, unknown>
}
