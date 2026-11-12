// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type ProductBulkDestroyParams = {
  /**
   * Ids outside this seller's catalog are ignored; products the store refuses to delete are counted
   * in `skipped_count`.
   */
  ids: string[]
}
