// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type AccountUpdateParams = {
  first_name?: string
  last_name?: string
  /** The panel's display language, as a code the panel ships. */
  selected_locale?: string
  /**
   * A `signed_id` from `POST /files` to set the photo, or `null` to remove it. Omit to leave the
   * current one alone.
   */
  avatar_signed_id?: string | null
}
