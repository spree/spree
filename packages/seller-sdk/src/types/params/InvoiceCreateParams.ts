// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { CurrencyCode } from '../generated'

export type InvoiceCreateParams = {
  /** A credit note corrects an earlier invoice or receipt and carries negative totals. */
  kind: 'invoice' | 'receipt' | 'credit_note'
  /**
   * The number the issuing system gave it. Unique per issuer and kind; never Spree's order number.
   */
  number: string
  issued_on: string
  /** When the goods or service were supplied, if not the issue date. */
  supplied_on?: string | null
  /** Defaults to the order's or payout's currency. */
  currency?: CurrencyCode
  /** Gross total. Zero or more, or zero or less for a credit note. */
  total: string
  net_total?: string | null
  tax_total?: string | null
  /** The invoice a credit note corrects, on the same order or payout. */
  original_invoice_id?: string | null
  /** The issuing system's own id. */
  external_reference?: string | null
  /** A PDF's `signed_id` from `files.upload()` with `visibility: 'private'`. */
  file_signed_id: string
  metadata?: Record<string, unknown>
}
