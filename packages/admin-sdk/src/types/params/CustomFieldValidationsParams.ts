// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { CustomFieldChoiceParams } from './CustomFieldChoiceParams'

export type CustomFieldValidationsParams = {
  /**
   * The value cannot be blank. Marked and checked by the forms that edit the value; the API accepts
   * a blank value.
   */
  required?: boolean
  /**
   * Inclusive lower bound: a character count for `short_text` and `long_text`, a number for
   * `number`, an ISO 8601 date or date-time for `date` and `date_time`.
   */
  min?: unknown
  /** Inclusive upper bound, in the same form as `min`. */
  max?: unknown
  /** For `choice` fields, required: the options in display order. Values must be unique. */
  choices?: CustomFieldChoiceParams[]
  /** For `choice` fields: several values may be chosen, and the value is a list. */
  multiple?: boolean
}
