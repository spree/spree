// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type CatalogAssignmentParams = {
  /** Buyer audiences only. A company assignment covers its subtree. */
  assignable_type: 'customer_group' | 'company'
  assignable_id: string
}
