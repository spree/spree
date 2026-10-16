// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { CustomFieldValueParams } from './CustomFieldValueParams'
import type { SellerAddressParams } from './SellerAddressParams'

export type ProfileUpdateParams = {
  name?: string
  contact_email?: string | null
  billing_email?: string | null
  /** Sanitized HTML: the seller's public description. */
  about?: string | null
  /** The business a commission invoice is made out to. */
  legal_name?: string | null
  registration_number?: string | null
  /** A `signed_id` from `POST /files`; `null` removes the image. */
  logo_signed_id?: string | null
  /** A `signed_id` from `POST /files`; `null` removes the image. */
  square_logo_signed_id?: string | null
  /** A `signed_id` from `POST /files`; `null` removes the image. */
  cover_photo_signed_id?: string | null
  billing_address?: SellerAddressParams
  /**
   * Answers to the custom fields this marketplace's onboarding asks for. A field nothing asked for
   * is ignored rather than written.
   */
  custom_fields?: CustomFieldValueParams[]
  /**
   * Stamps the moment the seller accepted the marketplace's terms. One-way: sending `false` does
   * not unmake the stamp.
   */
  accept_terms?: boolean
}
