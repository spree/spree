// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type TaxRateParams = {
  /** Customer-facing rate name. */
  name?: string
  /** The rate as a fraction. Send this or `rate_percent`. */
  rate?: string
  /** The rate as a percentage. */
  rate_percent?: string
  included_in_price?: boolean
  show_rate_in_label?: boolean
  tax_category_id?: string
  /** ISO country code. A rate naming no country taxes everywhere. */
  country_code?: string | null
  /** State abbreviation within that country. */
  state_code?: string | null
  metadata?: Record<string, unknown>
}
