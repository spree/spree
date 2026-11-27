// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type CustomFieldEntryParams = {
  /** The field as `namespace.key`, from `GET /store/custom_field_definitions`. */
  key: string
  /**
   * A string for text, date and single choice fields (date-times in ISO 8601), a decimal string for
   * number fields, true or false for boolean fields, and a list of values for a choice field that
   * allows several. Blank removes the value.
   */
  value?: unknown
}
