// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { CommissionRuleDraftParams } from './CommissionRuleDraftParams'

export type CommissionRateUpdateParams = {
  name?: string
  /** Your own identifier for this rate; unique per store. */
  code?: string | null
  enabled?: boolean
  /**
   * Place in the list. Rates resolve top-down and the first whose rules match wins, so 1 is tried
   * first. New rates are created at the top; send this to move one. A rate with no rules matches
   * every sale, so the marketplace default belongs at the bottom.
   */
  position?: number
  /** `percentage` charges a share of the sale; `fixed` charges a flat fee. */
  kind?: 'percentage' | 'fixed'
  /** A percentage (10 = 10%) or a flat amount, per `kind`. */
  value?: string
  /**
   * Charge on the price including the customer's VAT. Left off, commission is charged on the
   * seller's net revenue, which is the usual basis where the fee is taxed as its own supply.
   */
  tax_inclusive?: boolean
  /** Also charge commission on the seller's delivery revenue. Percentage rates only. */
  include_shipping?: boolean
  /**
   * VAT on the commission itself, as a fraction rather than a percentage. Null lets the store's tax
   * engine answer for the seller's jurisdiction.
   */
  commission_tax_rate?: string | null
  metadata?: Record<string, unknown>
  /**
   * What a flat fee charges, keyed by currency, as decimal strings. A sale in a currency with no
   * amount falls to the next matching rate. Replaces the whole set.
   */
  amounts?: Record<string, unknown>
  /**
   * The floor and cap a percentage charges within, keyed by currency: `{ min_amount, max_amount }`
   * decimal strings. A sale in a currency with no bounds is charged unbounded. Replaces the whole
   * set.
   */
  bounds?: Record<string, unknown>
  /** The full targeting; what you send replaces what the rate holds. */
  rules?: CommissionRuleDraftParams[]
}
