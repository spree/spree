// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { CountryCode } from '../generated'

export type DeliveryZoneMemberParams = {
  member_type: 'country' | 'state' | 'postal_code'
  country_code?: CountryCode
  /**
   * A subdivision code or name. Without `country_code` the country is inferred when only one
   * country matches.
   */
  state_code?: string
  postal_code_prefix?: string
  postal_code_from?: string
  postal_code_to?: string
}
