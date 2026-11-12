// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type LineItemInputParams = {
  variant_id: string
  /** Defaults to 1. */
  quantity?: number
  /** Key-value metadata, merged with what the line item has. */
  metadata?: Record<string, unknown>
  options?: Record<string, unknown>
}
