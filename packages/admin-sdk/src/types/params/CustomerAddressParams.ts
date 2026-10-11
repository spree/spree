// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { CountryCode } from '../generated'

export type CustomerAddressParams = {
  first_name?: string
  last_name?: string
  company?: string
  address1?: string
  address2?: string
  city?: string
  postal_code?: string
  phone?: string
  label?: string
  /** Legacy spelling of `postal_code`; send only one of the two. */
  zipcode?: string
  /** ISO 3166-1 alpha-2 code, such as `US`. */
  country_code?: CountryCode
  /** The state or province abbreviation, such as `NY`. */
  state_code?: string
  /** For countries without states in the database. */
  state_name?: string
  alternative_phone?: string
  quick_checkout?: boolean
  /** Makes this the customer's default address of that kind. */
  is_default_billing?: boolean
  /** Makes this the customer's default address of that kind. */
  is_default_shipping?: boolean
}
