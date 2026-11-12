// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type ReturnRefundParams = {
  /** Defaults to the value of what was actually received. */
  amount?: string
  /**
   * `store_credit` issues credit immediately; `original_payment` (the default) refunds through the
   * gateway that took the money.
   */
  refund_method?: 'original_payment' | 'store_credit'
}
