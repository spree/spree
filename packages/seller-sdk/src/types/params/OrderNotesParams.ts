// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type OrderNotesParams = {
  /** What the buyer asked for. */
  customer_note?: string | null
  /**
   * The seller's own working note, as HTML. Sanitized on save; `internal_note_html` reads it back.
   */
  internal_note?: string | null
}
