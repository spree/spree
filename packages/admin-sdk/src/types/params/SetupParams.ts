// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { CountryCode } from '../generated'
import type { CurrencyCode } from '../generated'

export type SetupParams = {
  /** The one-time token from the install output. */
  setup_token: string
  email: string
  password: string
  password_confirmation?: string
  first_name?: string
  last_name?: string
  store_name?: string
  /**
   * ISO 3166-1 alpha-2 country the store sells from. It determines the default market, the
   * warehouse, the delivery zones and the currency.
   */
  country_code: CountryCode
  /** Storefront locale. Defaults to the country's own language. */
  locale?: string
  /**
   * ISO 4217 currency. Defaults to the country's own currency: pass one only when the store prices
   * in something else.
   */
  currency?: CurrencyCode
  /**
   * Load the demo catalog, customers and orders in the background once the admin account exists.
   * The load takes minutes, so the response does not wait for it.
   */
  sample_data?: boolean
}
