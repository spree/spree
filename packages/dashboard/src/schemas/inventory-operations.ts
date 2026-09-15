/**
 * Canonical status values for the two inventory documents, matching
 * `Spree::HasStatus` on the models. Values only — labels are built at render
 * time from `admin.stock_transfers.statuses.*` and
 * `admin.purchase_orders.statuses.*`.
 */
export const STOCK_TRANSFER_STATUSES = [
  'draft',
  'ready_to_ship',
  'in_transit',
  'partially_received',
  'received',
  'over_received',
  'canceled',
] as const

export type StockTransferStatus = (typeof STOCK_TRANSFER_STATUSES)[number]

export const PURCHASE_ORDER_STATUSES = [
  'draft',
  'ordered',
  'partially_received',
  'received',
  'over_received',
  'canceled',
] as const

export type PurchaseOrderStatus = (typeof PURCHASE_ORDER_STATUSES)[number]

/**
 * Why a delivery refused units, matching `Spree::StockReceiptItem::REJECTION_REASONS`.
 * A closed list: the server accepts nothing else, and a fixed vocabulary is
 * what makes the figures worth reporting on.
 */
export const REJECTION_REASONS = ['damaged', 'wrong_item', 'expired', 'other'] as const

export type RejectionReason = (typeof REJECTION_REASONS)[number]

/** What happens to units still in flight when a shipped transfer is called off. */
export const IN_TRANSIT_RESOLUTIONS = ['restock', 'write_off'] as const

export type InTransitResolution = (typeof IN_TRANSIT_RESOLUTIONS)[number]

/** A transfer whose units have left the source but not all arrived. */
export function isInFlight(status: string): boolean {
  return status === 'in_transit' || status === 'partially_received'
}

/** Nothing more will arrive on a document in one of these. */
export function isClosed(status: string): boolean {
  return status === 'received' || status === 'over_received' || status === 'canceled'
}
