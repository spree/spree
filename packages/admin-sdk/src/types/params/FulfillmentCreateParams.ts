// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type FulfillmentCreateParams = {
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
  stock_location_id: string
  /**
   * The only fulfillment of this order to move units from, its exchange and claim replacements
   * included: how a canceled replacement is sent again. Omitted, the customer's bought units are
   * taken from every unshipped fulfillment.
   */
  source_fulfillment_id?: string
  /**
   * Carrier tracking number, or a full `https://` tracking link, which is served back as
   * `tracking_url` unchanged.
   */
  tracking?: string
  /**
   * Delivery method attached as the selected rate. Defaults to the delivery method of the fully
   * drained source fulfillments.
   */
  delivery_method_id?: string
  /**
   * Explicit shipping cost, such as the 3PL price. Defaults to the summed cost of the fully drained
   * source fulfillments, which keeps the order total unchanged. Persists only with
   * `status: shipped`; pending fulfillments are re-priced by the rate engine.
   */
  cost?: string
  /** Pass `shipped` to register an already-shipped external fulfillment. */
  status?: 'shipped'
  metadata?: Record<string, unknown>
  /** Line item quantities to fulfill. Omit to fulfill every unit not yet shipped. */
  items?: {
    item_id: string
    quantity: number
  }[]
}
