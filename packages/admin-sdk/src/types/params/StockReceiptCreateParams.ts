// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { StockReceiptItemParams } from './StockReceiptItemParams'

export type StockReceiptCreateParams = {
  /** The supplier's delivery note, or the carrier's reference. */
  reference?: string | null
  /** When the goods were counted in. Defaults to now. */
  received_at?: string | null
  notes?: string | null
  /**
   * Omit to book in everything still outstanding, intact. Naming lines, even none, records exactly
   * what the dock counted: `quantity_accepted` reaches the shelf; `quantity_rejected` is refused,
   * recorded with a `rejection_reason` and never stocked.
   */
  items?: StockReceiptItemParams[]
}
