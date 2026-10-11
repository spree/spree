// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { CountryCode } from '../generated'

export type OrderAddressParams = {
  first_name?: string
  last_name?: string
  address1?: string
  city?: string
  postal_code?: string
  zipcode?: string
  company?: string | null
  address2?: string | null
  phone?: string | null
  alternative_phone?: string | null
  state_code?: string | null
  state_name?: string | null
  label?: string | null
  country_code?: CountryCode
}
