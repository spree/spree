// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type ClaimResolveParams = {
  resolution: 'refund' | 'replacement' | 'refund_and_replacement'
  /** Defaults to `store_credit`. */
  refund_method?: 'original_payment' | 'store_credit'
  amount?: string | null
  /** Which claimed lines to replace. Omit to keep the lines the claim was opened with. */
  replacement_line_item_ids?: string[]
}
