// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type CreatePaymentSessionParams = {
  payment_method_id: string
  /** Defaults to the order total minus store credits. */
  amount?: string
  /** Provider-specific data passed to the gateway. */
  external_data?: Record<string, unknown>
}
