// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type CreateClaimParams = {
  items: {
    line_item_id: string
    quantity: number
    /** What is wrong with the item. */
    description?: string
  }[]
  /** One of the store's claim reasons. */
  reason_id?: string
  memo?: string
}
