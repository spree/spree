// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type RefundCreateParams = {
  payment_id: string
  amount: string
  /** Defaults to the store's first refund reason. */
  refund_reason_id?: string
}
