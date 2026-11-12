// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type FulfillmentFulfillParams = {
  /**
   * Line item quantities to ship. Omit to ship everything the fulfillment holds; a subset is split
   * onto a new fulfillment, which is the one that ships.
   */
  items?: {
    item_id: string
    quantity: number
  }[]
  /**
   * Carrier tracking number or a full `https://` tracking link, stored on the fulfillment that
   * ships.
   */
  tracking?: string
  /** Which carrier the number belongs to; detected from the number when omitted. */
  tracking_carrier?: string
  /**
   * Whether the customer gets the shipment email. Defaults to true; pass false to suppress it for
   * this dispatch only.
   */
  notify_customer?: boolean
  /** Hand the goods over even though the order is unpaid or holds backordered units. */
  force?: boolean
}
