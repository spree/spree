// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { CountryCode } from '../generated'

export type StockLocationCreateParams = {
  name: string
  admin_name?: string | null
  /** Set `false` to retire a location: there is no delete. */
  active?: boolean
  default?: boolean
  /** Categorizes the location. The values listed are the built-in ones; extensions may add more. */
  kind?: 'warehouse' | 'store' | 'fulfillment_center' | (string & {})
  propagate_all_variants?: boolean
  backorderable_default?: boolean
  address1?: string | null
  address2?: string | null
  city?: string | null
  zipcode?: string | null
  phone?: string | null
  company?: string | null
  /** ISO-3166 alpha-2 country code. */
  country_code?: CountryCode | null
  /** State or province abbreviation, resolved against the selected country's states. */
  state_code?: string | null
  /** Free-text state for countries that don't have a states list. */
  state_name?: string | null
  pickup_enabled?: boolean
  /**
   * `local` collects only items at this location; `any` lets items transfer in from other locations
   * (ship-to-store).
   */
  pickup_stock_policy?: 'local' | 'any'
  pickup_ready_in_minutes?: number | null
  /** Whether customers may send returns to this location. */
  returns_enabled?: boolean
  pickup_instructions?: string | null
}
