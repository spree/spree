// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type PaymentCaptureParams = {
  /** Captures part of the authorized amount, never more than the order still owes. Defaults to what the order still owes, up to the authorized amount. */
  amount?: string
}
