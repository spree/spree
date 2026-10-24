// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type DigitalAssetCreateParams = {
  /**
   * A `signed_id` from `files.upload()` with `visibility: 'private'`. On update it replaces the
   * file for everyone who already bought it.
   */
  signed_id: string
  /** Defaults to the product's default variant when omitted. */
  variant_id?: string
  /** Null means the store's download settings apply. */
  authorized_clicks?: number | null
  /** Null means the store's download settings apply. */
  authorized_days?: number | null
}
