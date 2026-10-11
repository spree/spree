// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type DiscountCreateParams = {
  label: string
  /** An amount in the order currency for a `flat` discount, or a percentage for a `percent` one. */
  value?: string
  /**
   * On create, an older spelling of `value`, read when `value` is absent. On update, the new amount
   * of the row.
   */
  amount?: string
  /** Defaults to `flat`. */
  value_type?: 'flat' | 'percent'
  /**
   * The line item the discount applies to. Omitted, the value is distributed across the line items.
   */
  line_item_id?: string | null
}
