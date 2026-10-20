// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type TaxExemptionReasonCreateParams = {
  name: string
  /** Whether the reason is offered on new records. */
  active?: boolean
  /**
   * What the tax provider receives for every certificate holding this reason — for Avalara, an
   * entity use code such as `G`. Saved in capitals. Changing it changes what those certificates
   * send from then on.
   */
  code: string
  metadata?: Record<string, unknown>
}
