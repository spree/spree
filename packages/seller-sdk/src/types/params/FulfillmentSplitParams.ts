// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type FulfillmentSplitParams = {
  /** The variant being moved out. */
  variant_id: string
  quantity: number
  /** One of this seller's own stock locations. Defaults to the source fulfillment's location. */
  stock_location_id?: string
}
