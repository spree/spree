// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { CustomFieldEntryParams } from './CustomFieldEntryParams'

export type UpdateCustomerParams = {
  email?: string
  /**
   * Changing it signs the customer out everywhere: every refresh token is revoked, so sign in again
   * once the access token expires.
   */
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
  /**
   * Values for the customer fields shoppers fill in, listed by
   * `GET /store/custom_field_definitions?q[resource_type_eq]=customer`. Each is checked against its
   * field's rules; an unknown key is refused, and a required field cannot be left out at
   * registration or blanked later. Fields not named keep their values.
   */
  custom_fields?: CustomFieldEntryParams[]
}
