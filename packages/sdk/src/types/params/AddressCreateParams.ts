// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { CountryCode } from '../generated'

export type AddressCreateParams = {
  first_name: string
  last_name: string
  company?: string
  address1: string
  address2?: string
  city: string
  postal_code?: string
  phone?: string
  /** ISO 3166-1 alpha-2 country code, such as `US` or `DE`. */
  country_code: CountryCode
  /** ISO 3166-2 subdivision code without the country prefix, such as `CA` or `NY`. */
  state_code?: string
  /** The state name, for countries without predefined states. */
  state_name?: string
  /**
   * Relaxes validation (name, phone, postal code, street), for express checkouts that share a
   * partial address.
   */
  quick_checkout?: boolean
  /** @deprecated Use `country_code`. Removed in 6.1. */
  country_iso?: string
  /** @deprecated Use `state_code`. Removed in 6.1. */
  state_abbr?: string
  /** Makes this the default billing address. */
  is_default_billing?: boolean
  /** Makes this the default shipping address. */
  is_default_shipping?: boolean
}
