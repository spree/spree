// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type AddLineItemParams = {
  variant_id: string
  /** Defaults to 1. */
  quantity?: number
  /** Write-only key-value metadata. */
  metadata?: Record<string, unknown>
  /** Values for line item attributes an extension adds. */
  options?: Record<string, unknown>
}
