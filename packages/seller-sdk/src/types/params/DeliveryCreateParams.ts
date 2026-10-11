// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type DeliveryCreateParams = {
  /**
   * A carrier tracking number, a freight PRO or container number, or a full tracking link. A
   * corrected number resets the carrier status to `pending`.
   */
  tracking_number: string
  /** Free text; detected from the number's format when omitted. */
  carrier?: string
  service?: string
  tracking_url?: string
}
