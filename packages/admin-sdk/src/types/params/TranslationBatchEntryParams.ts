// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type TranslationBatchEntryParams = {
  /** Translatable resource type token, e.g. `option_type`. */
  resource_type: string
  resource_id: string
  /** Translated fields keyed by locale code, then by field name. */
  values: Record<string, unknown>
}
