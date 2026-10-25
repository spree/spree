// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type CompletePaymentSessionParams = {
  /** Provider-specific session result token. */
  session_result?: string
  /** Provider-specific completion data. */
  external_data?: Record<string, unknown>
}
