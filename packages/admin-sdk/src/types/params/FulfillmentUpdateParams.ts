// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type FulfillmentUpdateParams = {
  /**
   * Identities the record has in external systems, keyed by system: the same
   * `{ system: external_id }` map the Admin API renders, so what you read can be sent straight
   * back. Systems you do not name keep the reference they have. A list of `{ system, external_id }`
   * entries is accepted too.
   */
  external_references?: Record<string, unknown>
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
  /**
   * On create, an explicit shipping cost, such as the 3PL price. Defaults to the summed cost of the
   * fully drained source fulfillments, which keeps the order total unchanged. Persists only with
   * `status: shipped`; pending fulfillments are re-priced by the rate engine. On update, a delivery
   * cost set by hand, which no re-quote, rate change or move to another stock location changes
   * afterwards: send null to go back to the selected delivery rate's price, or omit it to leave the
   * cost as it is.
   */
  cost?: string | null
}
