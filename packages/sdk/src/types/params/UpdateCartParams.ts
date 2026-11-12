// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { CartAddressParams } from './CartAddressParams'
import type { CurrencyCode } from '../generated'
import type { LineItemInputParams } from './LineItemInputParams'
import type { LocaleCode } from '../generated'

export type UpdateCartParams = {
  email?: string
  customer_note?: string
  market_id?: string
  currency?: CurrencyCode
  locale?: LocaleCode
  /**
   * An existing address to ship to, from the buyer's address book or from the book of the company
   * the cart is for. List both with `GET /store/carts/:id/addresses`.
   */
  shipping_address_id?: string
  /**
   * An existing address to bill, from the buyer's address book or from the book of the company the
   * cart is for. List both with `GET /store/carts/:id/addresses`.
   */
  billing_address_id?: string
  preferred_stock_location_id?: string
  /**
   * The company node this purchase is for. The buyer must have standing over it: a membership on
   * that node or one of its ancestors. Null clears it, and with it the company's catalog, pricing
   * and tax anchoring.
   */
  company_id?: string | null
  /**
   * The buyer's own purchase-order reference. Their accounting reconciles the order, the invoice
   * and the payment against it. Blank clears it.
   */
  po_number?: string | null
  /**
   * The `signed_id` of the buyer's purchase order, from `POST /store/carts/:id/po_document`. Blank
   * detaches the document.
   */
  po_document_signed_id?: string | null
  /** When true, copies the shipping address to the billing address. */
  use_shipping?: boolean
  /** A new shipping address. */
  shipping_address?: CartAddressParams
  /** A new billing address. */
  billing_address?: CartAddressParams
  /** Write-only key-value metadata, merged with what the cart has. */
  metadata?: Record<string, unknown>
  /** Items to upsert: sets the quantity of a variant already in the cart, adds the others. */
  items?: LineItemInputParams[]
}
