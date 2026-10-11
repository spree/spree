// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type ProductDigitalAssetParams = {
  id?: string
  signed_id?: string
  variant_id?: string
  /** A provider shorthand from the digital asset providers endpoint. */
  provider_type?: string
  /** Values for the provider's settings schema, keyed by field name. */
  provider_settings?: Record<string, unknown>
  /** Null means the store's download settings apply. */
  authorized_clicks?: number | null
  /** Null means the store's download settings apply. */
  authorized_days?: number | null
}
