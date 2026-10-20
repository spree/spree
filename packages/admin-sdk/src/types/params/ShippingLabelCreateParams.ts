// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { CurrencyCode } from '../generated'

export type ShippingLabelCreateParams = {
  /**
   * A `signed_id` from `files.upload()`. Its presence records a label bought elsewhere instead of
   * buying one; without it the body is ignored and the label is bought through the carrier.
   */
  file_signed_id?: string
  /** The number printed on an uploaded label. Required with `file_signed_id`. */
  tracking_number?: string
  /**
   * Free text; a forwarder's name is as valid as a carrier slug. Detected from the number when
   * omitted.
   */
  carrier?: string
  /** Carrier service the label was bought at. */
  service?: string
  /**
   * What the merchant paid the carrier. Accounting data only; it never touches the order's shipping
   * charge.
   */
  cost?: string
  /** Currency of the cost. */
  currency?: CurrencyCode
  /** Taken from the file when omitted. */
  file_format?: 'pdf' | 'png' | 'zpl'
  /** Tracking page for the consignment the label mints. */
  tracking_url?: string
}
