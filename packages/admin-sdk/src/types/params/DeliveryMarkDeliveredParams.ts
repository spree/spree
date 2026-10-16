// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type DeliveryMarkDeliveredParams = {
  /** When it arrived. Defaults to now. */
  delivered_at?: string
  /**
   * Whether the customer gets a delivery notification once the parcel completes. Defaults to true.
   */
  notify_customer?: boolean
}
