// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type EmailTemplateDraftParams = {
  /** A language code, or `any` (the default) for the version every language uses. */
  language?: string
  subject?: string | null
  body?: string
  /**
   * The `lock_version` the draft was loaded with, or null when there was no draft; a save from an
   * older copy is refused with 409. Omit it to save without checking.
   */
  lock_version?: number | null
  /** Marks the draft as based on Spree's current default, after reviewing what changed in it. */
  rebase?: boolean
}
