// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { CustomFieldChoiceParams } from './CustomFieldChoiceParams'

export type CustomFieldValidationsParams = {
  /**
   * The value cannot be blank. Marked and checked by the forms that edit the value, and the Admin
   * API accepts a blank value. Where shoppers fill a `storefront_writable` field in, it is
   * enforced: a required order field holds up checkout, and a required customer field must be given
   * at registration.
   */
  required?: boolean
  /**
   * Inclusive lower bound: a character count for `short_text` and `long_text`, a number for
   * `number`, an ISO 8601 date or date-time for `date` and `date_time`.
   */
  min?: unknown
  /** Inclusive upper bound, in the same form as `min`. */
  max?: unknown
  /**
   * For `short_text` and `long_text`: a Ruby regular expression the whole value must match, so no
   * anchors are needed. At most 255 characters; backreferences are refused, so every pattern is
   * checked in linear time.
   */
  regex?: string
  /** For `choice` fields, required: the options in display order. Values must be unique. */
  choices?: CustomFieldChoiceParams[]
  /** For `choice` fields: several values may be chosen, and the value is a list. */
  multiple?: boolean
}
