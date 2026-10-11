// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type FulfillmentUpdateParams = {
  /**
   * The location the fulfillment ships from. On update, moving it re-prices the fulfillment against
   * that location's rates.
   */
  stock_location_id?: string
  /**
   * Carrier tracking number, or a full `https://` tracking link, which is served back as
   * `tracking_url` unchanged.
   */
  tracking?: string
  /**
   * Which carrier the tracking number belongs to: a slug from the tracking carriers endpoint. Left
   * blank, it is detected from the number's format where possible.
   */
  tracking_carrier?: string
  selected_delivery_rate_id?: string
}
