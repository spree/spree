// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type FeeCreateParams = {
  label: string
  amount: string
  /** Defaults to `surcharge`. The values listed are the built-in ones; extensions may add more. */
  kind?: 'surcharge' | 'handling' | 'gift_wrap' | 'cod' | 'payment' | 'duty' | 'exchange' | (string & {})
  /** The line item or fulfillment the fee belongs to. Omitted, the fee is order-level. */
  line_item_id?: string | null
  /** The line item or fulfillment the fee belongs to. Omitted, the fee is order-level. */
  fulfillment_id?: string | null
}
