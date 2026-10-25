// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type SellerTaxIdentifierUpdateParams = {
  /**
   * The registration the number belongs to, such as `eu_vat` or `gb_vat`. Any kind is accepted; one
   * with a registered validator is checked by it. Built-in: `eu_vat`. Extensions may register more.
   * One registration per kind.
   */
  kind?: string
  /** A number the validator for its kind refuses is rejected rather than stored. */
  value?: string
}
