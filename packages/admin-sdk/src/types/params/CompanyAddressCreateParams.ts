// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { CountryCode } from '../generated'

export type CompanyAddressCreateParams = {
  first_name: string
  last_name: string
  company?: string
  address1: string
  address2?: string
  city: string
  postal_code?: string
  phone?: string
  label?: string
  /** ISO 3166-1 alpha-2 code, such as `US`. */
  country_code: CountryCode
  /** The state or province abbreviation, such as `NY`. */
  state_code?: string
  /** For countries without states in the database. */
  state_name?: string
  /**
   * True makes this the default address of that kind, false gives the slot up, and leaving it out
   * keeps the current default.
   */
  default_billing?: boolean
  /**
   * True makes this the default address of that kind, false gives the slot up, and leaving it out
   * keeps the current default.
   */
  default_shipping?: boolean
}
