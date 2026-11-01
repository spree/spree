// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type CreateOrderDocumentParams = {
  label: string
  /**
   * A `signed_id` from `files.upload()` with `visibility: 'private'`. PDF, image, office document
   * or CSV.
   */
  file_signed_id: string
}
