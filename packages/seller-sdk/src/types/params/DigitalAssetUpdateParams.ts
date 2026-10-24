// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type DigitalAssetUpdateParams = {
  /**
   * A `signed_id` from `files.upload()` with `visibility: 'private'`. On update it replaces the
   * file for everyone who already bought it. A seller's file must be of a content type the
   * marketplace accepts, judged from its bytes.
   */
  signed_id?: string
  /**
   * On create, defaults to the product's default variant when omitted. On update, omitting it keeps
   * the current variant.
   */
  variant_id?: string
  /** Null means the store's download settings apply. */
  authorized_clicks?: number | null
  /** Null means the store's download settings apply. */
  authorized_days?: number | null
}
