// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type UpdateCustomerParams = {
  email?: string
  password?: string
  password_confirmation?: string
  /** Required when changing the email or the password. */
  current_password?: string
  first_name?: string
  last_name?: string
  phone?: string
  accepts_email_marketing?: boolean
  /** Write-only key-value metadata. */
  metadata?: Record<string, unknown>
}
