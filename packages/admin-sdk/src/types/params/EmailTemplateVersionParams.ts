// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type EmailTemplateVersionParams = {
  /** A language code, or `any` (the default) for the version every language uses. */
  language?: string
  /** The draft's `lock_version` as reviewed. A draft saved since is refused with 409. */
  lock_version?: number
}
