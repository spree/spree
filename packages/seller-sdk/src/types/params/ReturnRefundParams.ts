// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type ReturnRefundParams = {
  amount?: string | null
  /** Defaults to `original_payment`. */
  refund_method?: 'original_payment' | 'store_credit'
}
