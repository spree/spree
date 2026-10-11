// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type ReturnCreateParams = {
  /** Fulfilled units coming back, and how many of each. */
  items: {
    fulfillment_item_id: string
    quantity: number
  }[]
  /** Where the goods come back to. Defaults to the location that shipped them. */
  stock_location_id?: string
  /** One of the store's return reasons. */
  reason_id?: string
  memo?: string
}
