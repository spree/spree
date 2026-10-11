// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type PriceParams = {
  currency: string
  /**
   * A canonical decimal string (`"1234.56"`: period decimal, no grouping). The API does not parse
   * localized input.
   */
  amount: string
  compare_at_amount?: string | null
}
