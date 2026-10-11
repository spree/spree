// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type GiftCardBatchCreateParams = {
  /** Lowercased and prepended to every generated code. */
  prefix: string
  /** The amount of each card, greater than zero. */
  amount: string
  /**
   * How many cards to generate. Capped at `gift_card_batch_limit`; batches over
   * `gift_card_batch_web_limit` generate in the background.
   */
  codes_count: number
  /** ISO 4217 currency code. Defaults to the store currency. */
  currency?: string
  expires_at?: string | null
}
