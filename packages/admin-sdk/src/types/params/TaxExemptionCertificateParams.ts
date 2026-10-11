// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type TaxExemptionCertificateParams = {
  /** Required when creating. */
  certificate_number?: string
  /** Becomes the tax provider's entity use code. Required when creating. */
  reason_code?: string
  issuing_authority?: string | null
  issued_at?: string | null
  expires_at?: string | null
  /** Where the certificate holds. Omit both for one valid everywhere. */
  country_code?: string | null
  /** Where the certificate holds. Omit both for one valid everywhere. */
  state_code?: string | null
  /** A `signed_id` from `files.upload()` with `visibility: 'private'`. */
  document_signed_id?: string
  metadata?: Record<string, unknown>
}
