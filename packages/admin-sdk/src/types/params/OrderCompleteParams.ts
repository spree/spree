// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type OrderCompleteParams = {
  payment_pending?: boolean
  /** Send the order confirmation email after completion. */
  notify_customer?: boolean
}
