// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type ProductBulkStatusParams = {
  ids: string[]
  /**
   * A listing goes on sale only when the marketplace approves it, so there is no bulk route onto
   * `active`.
   */
  status: 'draft' | 'archived'
}
