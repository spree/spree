// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { CurrencyCode } from '../generated'

export type VariantSalesContextParams = {
  /**
   * A draft order to sell to: lists only what its buyer can be sold on its channel, priced in its
   * market. Needs `read_orders`, and cannot be combined with the fields below.
   */
  order_id?: string
  /** Prices in this market and lists only variants with a price in its currency. */
  market_id?: string
  /** Lists only variants published on this channel. Defaults to the store default channel. */
  channel_id?: string
  /** Narrows to the customer's catalogs and prices as they would pay. Needs `read_customers`. */
  customer_id?: string
  /** Narrows to the company's catalogs and prices under its agreement. Needs `read_customers`. */
  company_id?: string
  /**
   * Lists only variants with a price in this currency. With `market_id` it must be the market's
   * currency.
   */
  currency?: CurrencyCode
}
