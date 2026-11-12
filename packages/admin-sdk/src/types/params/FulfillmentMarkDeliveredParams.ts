// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type FulfillmentMarkDeliveredParams = {
  /** When it arrived. Defaults to now; return windows run from this time. */
  delivered_at?: string
  /** Whether the customer gets a delivery notification. Defaults to true. */
  notify_customer?: boolean
}
