// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type PurchaseOrderItemParams = {
  variant_id: string
  quantity_ordered: number
  /** What the merchant agreed to pay per unit. */
  unit_cost: string
}
