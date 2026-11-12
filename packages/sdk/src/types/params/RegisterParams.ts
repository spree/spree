// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type RegisterParams = {
  email: string
  password: string
  password_confirmation?: string
  first_name?: string
  last_name?: string
  phone?: string
  accepts_email_marketing?: boolean
  /** Write-only key-value metadata. */
  metadata?: Record<string, unknown>
  /**
   * Whether the customer ticked the storefront's terms of service box. Recorded as their consent.
   */
  terms_of_service?: boolean
}
