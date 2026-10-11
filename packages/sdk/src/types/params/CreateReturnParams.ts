// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type CreateReturnParams = {
  items: {
    /** The shipped unit coming back. */
    fulfillment_item_id: string
    quantity: number
  }[]
  /** One of the store's return reasons. */
  reason_id?: string
  memo?: string
}
