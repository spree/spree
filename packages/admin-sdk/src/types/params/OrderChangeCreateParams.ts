// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type OrderChangeCreateParams = {
  /** The changes, applied in order. */
  actions: {
    /**
     * `add_item` takes `variant_id` and `quantity`; `update_item` takes `line_item_id` and the new
     * `quantity`; `remove_item` takes `line_item_id`. `add_discount` takes `label` and `value`,
     * with `value_type` and `line_item_id` optional; `update_discount` takes `discount_id` and a
     * new `label` or `amount`; `remove_discount` takes `discount_id`. The values listed are the
     * built-in ones; extensions may add more.
     */
    kind: 'add_item' | 'update_item' | 'remove_item' | 'add_discount' | 'update_discount' | 'remove_discount' | (string & {})
    /**
     * A line item of this order. For `add_discount`, the line the discount applies to; omitted, it
     * is spread across the lines.
     */
    line_item_id?: string
    /** A variant of this store, for `add_item`. */
    variant_id?: string
    quantity?: number
    /** A manual discount of this order, for `update_discount` and `remove_discount`. */
    discount_id?: string
    /** The discount name, for `add_discount` and `update_discount`. */
    label?: string
    /**
     * For `add_discount`: an amount in the order currency for a `flat` discount, or a percentage
     * for a `percent` one.
     */
    value?: string
    /** For `add_discount`. Defaults to `flat`. */
    value_type?: 'flat' | 'percent'
    /** For `update_discount`: the row's new amount in the order currency, zero or less. */
    amount?: string
  }[]
  /**
   * Apply the change at once. Omitted or false, it waits as `requested` for a confirm or cancel.
   */
  confirm?: boolean
  metadata?: Record<string, unknown>
}
