// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type FulfillmentUpdateParams = {
  tracking?: string | null
  tracking_carrier?: string | null
  /** One of this seller's own stock locations; the rates requote from there. */
  stock_location_id?: string
  /** One of the rates quoted for this parcel from its current origin. */
  selected_delivery_rate_id?: string
}
