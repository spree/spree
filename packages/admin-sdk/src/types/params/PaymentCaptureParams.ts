// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type PaymentCaptureParams = {
  /**
   * Captures part of the authorized amount. Defaults to all of it, or to what the order still owes
   * when that is less.
   */
  amount?: string
}
