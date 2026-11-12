// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type SavedReportCreateParams = {
  name: string
  description?: string | null
  /** A reporting query, validated against the reporting registry on save. */
  query: Record<string, unknown>
}
