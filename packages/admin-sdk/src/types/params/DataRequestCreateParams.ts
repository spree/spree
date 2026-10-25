// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type DataRequestCreateParams = {
  customer_id: string
  /**
   * `access` asks for a copy of the customer's personal data; `erasure` asks for it to be erased.
   */
  kind: 'access' | 'erasure'
}
