// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { StockTransferItemParams } from './StockTransferItemParams'

export type StockTransferCreateParams = {
  source_location_id: string
  destination_location_id: string
  /** The merchant's own label for the trip. `null` clears it. */
  reference?: string | null
  notes?: string | null
  /**
   * A draft may open empty and gain lines as the merchant packs. Sending the list replaces whatever
   * the draft currently holds.
   */
  items?: StockTransferItemParams[]
  metadata?: Record<string, unknown> | null
}
