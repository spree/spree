// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type CompanyAddressParams = {
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
  /**
   * True makes this the node's default billing address, false gives that up, and leaving it out
   * changes nothing.
   */
  default_billing?: boolean
  /**
   * True makes this the node's default shipping address, false gives that up, and leaving it out
   * changes nothing.
   */
  default_shipping?: boolean
}
