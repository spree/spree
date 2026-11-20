// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type ClaimCreateParams = {
  items: {
    line_item_id: string
    quantity: number
    description?: string | null
    send_replacement?: boolean
    /** One of this seller's own variants. */
    replacement_variant_id?: string | null
    /** Tax included. What the customer paid for these units when left out. */
    refund_amount?: string | null
  }[]
  reason_id?: string | null
  memo?: string | null
}
