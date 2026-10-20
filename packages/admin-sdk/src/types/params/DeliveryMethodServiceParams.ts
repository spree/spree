// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type DeliveryMethodServiceParams = {
  /** Prefixed row ID (`dms_...`) when updating an existing row. */
  id?: string
  /** Carrier identifier as the provider's API knows it. */
  carrier: string
  /** Service identifier as the provider's API knows it. */
  service: string
  /** Display label shown to customers instead of the carrier-derived name. */
  label?: string | null
  /** Overrides the method-level flat markup for this service. */
  markup_flat?: string | null
  /** Overrides the method-level percentage markup for this service. */
  markup_percent?: string | null
  position?: number
}
