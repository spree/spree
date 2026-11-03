// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { GiftCardRecipientParams } from './GiftCardRecipientParams'

export type AddLineItemParams = {
  variant_id: string
  /** Defaults to 1. */
  quantity?: number
  /** Write-only key-value metadata. */
  metadata?: Record<string, unknown>
  /** Values for line item attributes an extension adds. */
  options?: Record<string, unknown>
  /**
   * Who a gift card is for; only accepted when the variant is a gift card. Without it the card is
   * emailed to the order email. Adding the same denomination for a different recipient creates a
   * separate line.
   */
  recipient?: GiftCardRecipientParams
}
