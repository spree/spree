// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type AddressInputParams = {
  first_name?: string
  last_name?: string
  /** Legacy spelling of `first_name` / `last_name`; send only one of the two. */
  firstname?: string
  /** Legacy spelling of `first_name` / `last_name`; send only one of the two. */
  lastname?: string
  address1?: string
  address2?: string
  city?: string
  postal_code?: string
  /** Legacy spelling of `postal_code`; send only one of the two. */
  zipcode?: string
  country_code?: string
  state_code?: string
  /** For countries without states in the database. */
  state_name?: string
  phone?: string
  alternative_phone?: string
  company?: string
  label?: string
}
