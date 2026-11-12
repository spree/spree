// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type BulkTagsParams = {
  /**
   * The records to change. Records the caller cannot update are skipped; an empty list changes
   * nothing.
   */
  ids: string[]
  tags: string[]
}
