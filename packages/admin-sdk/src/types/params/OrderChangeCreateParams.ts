// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type OrderChangeCreateParams = {
  /** The changes, applied in order. */
  actions: {
    /**
     * `add_item` takes `variant_id` and `quantity`; `update_item` takes `line_item_id` and the new
     * `quantity`; `remove_item` takes `line_item_id`. The values listed are the built-in ones;
     * extensions may add more.
     */
    kind: 'add_item' | 'update_item' | 'remove_item' | (string & {})
    /** A line item of this order. */
    line_item_id?: string
    /** A variant of this store, for `add_item`. */
    variant_id?: string
    quantity?: number
  }[]
  /**
   * Apply the change at once. Omitted or false, it waits as `requested` for a confirm or cancel.
   */
  confirm?: boolean
  metadata?: Record<string, unknown>
}
