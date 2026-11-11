// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { GiftCardRecipientParams } from './GiftCardRecipientParams'

export type UpdateLineItemParams = {
  /** At least 1. Remove an item with DELETE. */
  quantity?: number
  /** Write-only key-value metadata, merged with what the line item has. */
  metadata?: Record<string, unknown>
  /** Replaces who a gift card line is for. Only accepted on a gift card line. */
  recipient?: GiftCardRecipientParams
}
