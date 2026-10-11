// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type GiftCardCreateParams = {
  /** Greater than zero. */
  amount: string
  /** ISO 4217 currency code. Defaults to the store currency. */
  currency?: string
  /** Generated when omitted. */
  code?: string
  expires_at?: string | null
  /** The customer the card belongs to. Needs the `read_customers` permission; null detaches it. */
  customer_id?: string | null
}
