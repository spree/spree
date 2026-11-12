// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type ExchangeFulfillParams = {
  /**
   * How a credit is returned when the replacements cost less than what came back. Defaults to
   * `store_credit`. A balance the customer owes is left for the merchant to collect.
   */
  refund_method?: 'original_payment' | 'store_credit'
}
