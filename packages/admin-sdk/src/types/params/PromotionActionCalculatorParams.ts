// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type PromotionActionCalculatorParams = {
  /**
   * The calculator kind, from `GET /promotion_actions/calculators`. Changing it swaps the
   * calculator.
   */
  type?: string
  /** Values for the calculator's settings, such as `amount` or `flat_percent`. */
  preferences?: Record<string, unknown>
}
