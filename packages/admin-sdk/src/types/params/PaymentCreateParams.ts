// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type PaymentCreateParams = {
  payment_method_id: string
  /** Defaults to the order total left after store credit. */
  amount?: string
  /**
   * A saved payment source of the order's customer (a credit card), for an off-session charge. Used
   * only by payment methods that require a source.
   */
  source_id?: string
}
