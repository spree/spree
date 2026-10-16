// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type CustomerUpdateParams = {
  email?: string
  first_name?: string
  last_name?: string
  phone?: string
  /** Optional: a customer created without one claims the account through a password reset. */
  password?: string
  /** Optional: a customer created without one claims the account through a password reset. */
  password_confirmation?: string
  selected_locale?: string
  /** A `signed_id` from `files.upload()`. */
  avatar_signed_id?: string
  accepts_email_marketing?: boolean
  /** Rich text HTML. Reads come back as this plus `internal_note_html`. */
  internal_note?: string
  metadata?: Record<string, unknown>
  tags?: string[]
  /** Replaces the customer's group membership. */
  customer_group_ids?: string[]
}
