// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type CartAddressParams = {
  /** An existing address of the customer to use. The other fields are then ignored. */
  id?: string
  first_name?: string
  last_name?: string
  company?: string
  address1?: string
  address2?: string
  city?: string
  postal_code?: string
  phone?: string
  /** ISO 3166-1 alpha-2 country code, such as `US` or `DE`. */
  country_code?: string
  /** ISO 3166-2 subdivision code without the country prefix, such as `CA` or `NY`. */
  state_code?: string
  /** The state name, for countries without predefined states. */
  state_name?: string
  /** Deprecated: use `country_code`. Accepted until 6.1. */
  country_iso?: string
  /** Deprecated: use `state_code`. Accepted until 6.1. */
  state_abbr?: string
  /**
   * Relaxes validation (name, phone, postal code, street), for express checkouts that share a
   * partial address.
   */
  quick_checkout?: boolean
}
