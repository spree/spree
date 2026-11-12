// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type MeUpdateParams = {
  /** The dashboard display language. */
  selected_locale?: string
  first_name?: string
  last_name?: string
  /**
   * A `signed_id` from `files.upload()` to set the avatar, or null to remove it. Omit it to keep
   * the current photo.
   */
  avatar_signed_id?: string | null
}
