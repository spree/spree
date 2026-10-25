// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type OrderCancelParams = {
  /** Why the order was canceled: the id of one of the store's cancellation reasons. */
  cancel_reason_id?: string
  /** Staff-facing note about the cancellation. */
  cancel_note?: string
  /** Whether this order's share of a payment shared across a split checkout is handed back. */
  refund_payments?: boolean
  /**
   * How much of that share to return. Defaults to all of it; refused on an order whose payment is
   * not shared.
   */
  refund_amount?: string
  /** Send the order cancellation email after canceling. */
  notify_customer?: boolean
}
