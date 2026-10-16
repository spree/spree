// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type TaxExemptionReasonUpdateParams = {
  name?: string
  /** Whether the reason is offered on new records. */
  active?: boolean
  /**
   * What certificates record and the tax provider receives — for Avalara, an entity use code such
   * as `G`. Fixed once a certificate records it.
   */
  code?: string
  metadata?: Record<string, unknown>
}
