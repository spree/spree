// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type ImportCompleteMappingParams = {
  /** Column assignments to apply before processing starts. */
  mappings?: {
    /** Canonical schema field name. */
    schema_field: string
    /** CSV header to read the field from; `null` unmaps the field. */
    file_column: string | null
  }[]
}
