// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type DigitalAssetCreateParams = {
  /**
   * A `signed_id` from `files.upload()` with `visibility: 'private'`. Required for an uploaded
   * file, omitted for a provider-backed asset. On update it replaces the file for everyone who
   * already bought it.
   */
  signed_id?: string
  /** Defaults to the product's default variant when omitted. */
  variant_id?: string
  /** A provider shorthand from the providers endpoint. Omit for an uploaded file. */
  provider_type?: string
  /** Values for the provider's settings schema, keyed by field name. */
  provider_settings?: Record<string, unknown>
  /** Null means the store's download settings apply. */
  authorized_clicks?: number | null
  /** Null means the store's download settings apply. */
  authorized_days?: number | null
}
