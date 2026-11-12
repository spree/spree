// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type StockReceiptItemParams = {
  /** The purchase order or transfer line. */
  id: string
  quantity_accepted?: number
  quantity_rejected?: number
  rejection_reason?: 'damaged' | 'wrong_item' | 'expired' | 'other' | null
  notes?: string | null
}
