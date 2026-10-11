// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { CurrencyCode } from '../generated'

export type ShippingLabelCreateParams = {
  /** A `signed_id` from `files.upload()`. */
  file_signed_id: string
  /** The number printed on the label. */
  tracking_number: string
  /**
   * Free text; a forwarder's name is as valid as a carrier slug. Detected from the number when
   * omitted.
   */
  carrier?: string
  /** Carrier service the label was bought at. */
  service?: string
  /**
   * What the seller paid the carrier. Accounting data only; it never touches the order's shipping
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
