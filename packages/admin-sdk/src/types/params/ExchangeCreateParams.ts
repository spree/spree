// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type ExchangeCreateParams = {
  /** Items coming back, and what goes out in their place. */
  items: {
    fulfillment_item_id: string
    new_variant_id: string
    quantity: number
  }[]
  /** Where the goods come back to. */
  stock_location_id?: string
  /** One of the store's return reasons. */
  reason_id?: string
  memo?: string
}
