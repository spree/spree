// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { AddressInputParams } from './AddressInputParams'
import type { CurrencyCode } from '../generated'
import type { LocaleCode } from '../generated'

export type OrderCreateParams = {
  /**
   * Identities the record has in external systems, keyed by system: the same
   * `{ system: external_id }` map the Admin API renders, so what you read can be sent straight
   * back. Systems you do not name keep the reference they have. A list of `{ system, external_id }`
   * entries is accepted too.
   */
  external_references?: Record<string, unknown>
  email?: string
  /** Null detaches the customer, leaving a guest order under its `email`. */
  customer_id?: string | null
  /**
   * Copies the saved default billing and shipping addresses onto the order. Sent with `company_id`,
   * it takes that company's defaults, inherited from its parent nodes when the company holds none
   * of its own; otherwise it takes the customer's.
   */
  use_customer_default_address?: boolean
  currency?: CurrencyCode
  market_id?: string
  /** Defaults to the store primary channel when omitted. */
  channel_id?: string
  locale?: LocaleCode
  /** Public, customer-visible note. */
  customer_note?: string
  /** Staff-only note. Rich text HTML; reads come back as this plus `internal_note_html`. */
  internal_note?: string
  /**
   * The buyer's own purchase-order reference. Searchable alongside the order number, and rendered
   * on every order-facing document.
   */
  po_number?: string
  /**
   * The `signed_id` of the buyer's purchase order, from `files.upload()` with
   * `visibility: 'private'`. Null removes the document the order carries.
   */
  po_document_signed_id?: string | null
  /**
   * An existing address from the customer's address book, or from the address book of the company
   * the order is for.
   */
  shipping_address_id?: string
  /**
   * An existing address from the customer's address book, or from the address book of the company
   * the order is for.
   */
  billing_address_id?: string
  /**
   * Stock location to prefer for fulfillment. Order Routing's built-in preferred-location rule
   * ranks it first; routing falls back to the next rule when the location can't cover the cart.
   */
  preferred_stock_location_id?: string
  /**
   * Makes the order a company purchase, with that company's catalog prices and tax treatment. Null
   * makes a draft a plain customer order again.
   */
  company_id?: string | null
  /** Applied non-fatally: an invalid code does not block creation. */
  coupon_code?: string
  metadata?: Record<string, unknown>
  tags?: string[]
  shipping_address?: AddressInputParams
  billing_address?: AddressInputParams
  /** When true, copies the shipping address to the billing address. */
  use_shipping?: boolean
  /**
   * Line items to upsert, keyed by variant. An entry sets that variant's quantity, creating the
   * line item when the order has none; `quantity: 0` removes it. Variants you do not send are left
   * alone.
   */
  items?: {
    variant_id: string
    quantity?: number
    /**
     * Negotiated unit price; stamps `price_source: 'manual'`. Null reverts the line to catalog
     * pricing. Draft orders only.
     */
    price?: string | null
    metadata?: Record<string, unknown>
  }[]
}
