// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type GiftCardRecipientParams = {
  email: string
  name?: string
  /** At most 500 characters. */
  message?: string
  /**
   * When to email the gift card, at most 90 days ahead. Omit to send it as soon as the order is
   * paid.
   */
  send_at?: string
}
