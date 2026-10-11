// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type FeeUpdateParams = {
  label?: string
  amount?: string
  /** Defaults to `surcharge`. The values listed are the built-in ones; extensions may add more. */
  kind?: 'surcharge' | 'handling' | 'gift_wrap' | 'cod' | 'payment' | 'duty' | 'exchange' | (string & {})
}
