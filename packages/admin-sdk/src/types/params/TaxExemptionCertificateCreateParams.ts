// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { CountryCode } from '../generated'

export type TaxExemptionCertificateCreateParams = {
  certificate_number: string
  /**
   * The `code` of one of the store's active tax exemption reasons. The tax provider receives it.
   */
  reason_code: string
  issuing_authority?: string | null
  issued_at?: string | null
  expires_at?: string | null
  /** Where the certificate holds. Omit it and `state_code` for one valid everywhere. */
  country_code?: CountryCode | null
  state_code?: string | null
  /** A `signed_id` from `files.upload()` with `visibility: 'private'`. */
  document_signed_id?: string
  metadata?: Record<string, unknown>
}
