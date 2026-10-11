// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { CustomFieldValueParams } from './CustomFieldValueParams'
import type { SellerAddressParams } from './SellerAddressParams'

export type SellerUpdateParams = {
  /**
   * Identities the record has in external systems, keyed by system: the same
   * `{ system: external_id }` map the Admin API renders, so what you read can be sent straight
   * back. Systems you do not name keep the reference they have. A list of `{ system, external_id }`
   * entries is accepted too.
   */
  external_references?: Record<string, unknown>
  name?: string
  /** URL-safe slug, derived from the name when omitted. */
  slug?: string
  contact_email?: string | null
  billing_email?: string | null
  /** Sanitized HTML: the seller's public description. */
  about?: string | null
  /**
   * A `signed_id` from the files upload endpoint to set the image, `null` to remove it, or omit the
   * key to leave it untouched. The same applies to `square_logo_signed_id` and
   * `cover_photo_signed_id`.
   */
  logo_signed_id?: string | null
  square_logo_signed_id?: string | null
  cover_photo_signed_id?: string | null
  tax_remittance?: 'seller' | 'platform'
  payouts_schedule_interval?: 'daily' | 'weekly' | 'biweekly' | 'monthly' | 'manual' | null
  minimum_payout_amount?: string | null
  /** Set while the seller is away: the catalog stays but stops selling. */
  holiday_mode_until?: string | null
  legal_name?: string | null
  registration_number?: string | null
  metadata?: Record<string, unknown>
  /**
   * The seller's own billing address, written inline. There is no `billing_address_id`: an address
   * belongs to whoever it was created for, so it is never referenced by id.
   */
  billing_address?: SellerAddressParams
  /** Custom field values, each validated against its definition. */
  custom_fields?: CustomFieldValueParams[]
}
