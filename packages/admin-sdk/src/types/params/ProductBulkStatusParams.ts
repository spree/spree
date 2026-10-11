// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type ProductBulkStatusParams = {
  ids: string[]
  /** Products in review are skipped and counted in `skipped_in_review_count`. */
  status: 'draft' | 'active' | 'archived'
}
