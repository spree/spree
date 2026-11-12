// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type FulfillmentFulfillParams = {
  /** Carrier tracking number. */
  tracking?: string
  /** Carrier name. */
  tracking_carrier?: string
  /** Send the dispatch email (default true). */
  notify_customer?: boolean
  /** Ship only these lines; the rest split onto a new fulfillment. */
  items?: {
    /** Prefixed line item ID. */
    item_id: string
    quantity: number
  }[]
}
