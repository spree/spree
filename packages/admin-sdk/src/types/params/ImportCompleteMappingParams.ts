// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type ImportCompleteMappingParams = {
  /**
   * Column assignments to apply before processing starts. Omit to accept the ones assigned on
   * create.
   */
  mappings?: {
    /** A schema field name from the import's `schema_fields`. */
    schema_field: string
    /** The CSV header to read the field from; null unmaps the field. */
    file_column?: string | null
  }[]
}
