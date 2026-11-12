// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { CurrencyCode } from '../generated'

export type PriceCreateParams = {
  variant_id: string
  currency: CurrencyCode
  /**
   * The quantity a line must reach for this price to apply. Omit for the bottom rung of the ladder.
   * Anything above 1 requires a `price_list_id`.
   */
  min_quantity?: number
  amount?: string | null
  compare_at_amount?: string | null
  /** Omit or null for a base price; a price list for a list override. */
  price_list_id?: string | null
}
