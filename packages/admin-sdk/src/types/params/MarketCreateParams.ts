// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type MarketCreateParams = {
  /** Display name, unique within the store. */
  name: string
  /** ISO 4217 currency code. */
  currency: string
  /** Locale used as the market default. Always part of `supported_locales`. */
  default_locale: string
  /** Display prices with tax included. */
  tax_inclusive?: boolean
  /**
   * Shorthand of the tax engine that prices this market, from the tax providers endpoint. Null uses
   * the installation default.
   */
  tax_provider?: string | null
  /** Setting true demotes the previous default market of the store. */
  default?: boolean
  /** Sort order within the store; lower comes first. */
  position?: number
  /** Locales available in this market. The default locale is always included. */
  supported_locales?: string[]
  /** ISO 3166-1 alpha-2 codes of the countries in this market. At least one is required. */
  country_codes: string[]
}
