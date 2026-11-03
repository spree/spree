// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { CustomFieldValidationsParams } from './CustomFieldValidationsParams'

export type CustomFieldDefinitionUpdateParams = {
  /** Defaults to `custom`. */
  namespace?: string
  key?: string
  /** Human-readable name; defaults to the titleized `key`. */
  label?: string
  /**
   * When false, the definition is admin-only and never exposed in the Store API. Defaults to false.
   */
  storefront_visible?: boolean
  /**
   * Include values in storefront product text search. Supported for `short_text`, `long_text`,
   * `number`, `date`, `date_time` and `choice` fields; other types are refused.
   */
  searchable?: boolean
  /**
   * Allow storefront product listings to sort by this field (`sort=cf_{namespace}_{key}`).
   * Supported for `short_text`, `number`, `date`, `date_time` and single `choice` fields; other
   * types are refused.
   */
  sortable?: boolean
  /**
   * Rules for the values. Each applies only to the field types it names; values are checked when
   * written, so existing values stay readable after a rule changes. Replaces the stored rules; send
   * null to remove every rule.
   */
  validations?: CustomFieldValidationsParams | null
}
