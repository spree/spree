// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type EmailTemplateRestoreParams = {
  /** A language code, or `any` (the default) for the version every language uses. */
  language?: string
  /** The open draft's `lock_version`, or null when there is none; checked as when saving. */
  lock_version?: number | null
}
