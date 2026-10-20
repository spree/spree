// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type ReturnCreateParams = {
  items: {
    fulfillment_item_id: string
    quantity: number
  }[]
  reason_id?: string | null
  /** One of this seller's own stock locations, where the goods are restocked. */
  stock_location_id?: string | null
  memo?: string | null
}
