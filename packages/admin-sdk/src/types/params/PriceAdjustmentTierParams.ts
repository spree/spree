// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type PriceAdjustmentTierParams = {
  /** Above 1; quantity 1 is the list's own `price_adjustment_percentage`. */
  min_quantity: number
  /** Signed: negative discounts, positive marks up. */
  percentage: string
}
