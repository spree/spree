// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type CreateExchangeParams = {
  items: {
    /** The shipped unit coming back. */
    fulfillment_item_id: string
    /** A purchasable variant of the same product as the unit coming back. */
    new_variant_id: string
    quantity: number
  }[]
  /** One of the store's return reasons. */
  reason_id?: string
  memo?: string
}
