// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { PurchaseOrderItemParams } from './PurchaseOrderItemParams'

export type PurchaseOrderCreateParams = {
  supplier_id: string
  destination_location_id: string
  /** Defaults to the store's currency; set it for a foreign-currency order. */
  currency?: string | null
  /** The day the supplier promised. `null` clears it. */
  expected_at?: string | null
  /** The day after which the goods are no longer wanted. `null` clears it. */
  cancel_by?: string | null
  /** The supplier's own order number. `null` clears it. */
  reference?: string | null
  notes?: string | null
  /** Sending the list replaces whatever the order currently holds. */
  items?: PurchaseOrderItemParams[]
}
