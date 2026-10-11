// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type CustomerAddressParams = {
  first_name?: string
  last_name?: string
  company?: string
  address1?: string
  address2?: string
  city?: string
  postal_code?: string
  zipcode?: string
  phone?: string
  state_name?: string
  label?: string
  /** ISO 3166-1 alpha-2 code, such as `US`. */
  country_code?: string
  /** The state or province abbreviation, such as `NY`. */
  state_code?: string
  /** Older spellings of `first_name` and `last_name`. */
  firstname?: string
  /** Older spellings of `first_name` and `last_name`. */
  lastname?: string
  alternative_phone?: string
  quick_checkout?: boolean
  /** Makes this the customer's default address of that kind. */
  is_default_billing?: boolean
  /** Makes this the customer's default address of that kind. */
  is_default_shipping?: boolean
}
