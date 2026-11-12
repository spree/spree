// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type CreatePaymentSetupSessionParams = {
  payment_method_id: string
  /** Provider-specific data passed to the gateway. */
  external_data?: Record<string, unknown>
}
