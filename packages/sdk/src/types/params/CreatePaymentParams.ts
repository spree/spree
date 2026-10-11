// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type CreatePaymentParams = {
  /** A payment method that needs no payment session. */
  payment_method_id: string
  /** Defaults to the order total minus store credits. */
  amount?: string
  /** Key-value metadata to attach to the payment. */
  metadata?: Record<string, unknown>
}
