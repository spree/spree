// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type ClaimResolveParams = {
  /** Money back, a replacement shipment, or both. */
  resolution: 'refund' | 'replacement' | 'refund_and_replacement'
  /** Defaults to `store_credit`. */
  refund_method?: 'original_payment' | 'store_credit'
  /** Defaults to the claim total. */
  amount?: string
  /** Which claim lines to send a replacement for. Omit to keep what the claim was opened with. */
  replacement_line_item_ids?: string[]
}
