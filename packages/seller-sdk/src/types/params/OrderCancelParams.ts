// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type OrderCancelParams = {
  /** A reason from the order cancellation reasons endpoint. */
  cancel_reason_id?: string | null
  /** Free text beside the reason. */
  cancel_note?: string | null
  /** Hand back what the buyer paid for this order's goods. */
  refund_payments?: boolean
  /** Email the customer about the cancellation. */
  notify_customer?: boolean
}
