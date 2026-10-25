// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type ClaimCreateParams = {
  /** Affected items, and how each should be made right. */
  items: {
    line_item_id: string
    quantity: number
    description?: string
    send_replacement?: boolean
    /** Defaults to the variant that was bought. */
    replacement_variant_id?: string
    refund_amount?: string
  }[]
  /** One of the store's claim reasons. */
  reason_id?: string
  memo?: string
}
