// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type ImportCreateParams = {
  type: 'products'
  /** The `signed_id` of the uploaded CSV, from `POST /files` with `visibility: 'private'`. */
  attachment_signed_id: string
  /** CSV column separator. Defaults to a comma. */
  delimiter?: string
  /**
   * Absolute URL of the panel's imports view; the import-done email links back to it. Honored only
   * when it matches one of the store's allowed origins.
   */
  results_url?: string
}
