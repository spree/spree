// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { CustomFieldValidationsParams } from './CustomFieldValidationsParams'

export type CustomFieldDefinitionCreateParams = {
  /** Defaults to `custom`. */
  namespace?: string
  key: string
  /** Human-readable name; defaults to the titleized `key`. */
  label?: string
  /**
   * Custom field type token (`short_text`, `long_text`, `rich_text`, `number`, `boolean`, `json`,
   * `date`, `date_time`, `choice`). An extension type that has no token is named by its registered
   * class instead. Fixed once the definition is created.
   */
  field_type: string
  /**
   * Shorthand of the resource the field attaches to, from the resource types endpoint. Fixed once
   * the definition is created.
   */
  resource_type: string
  /**
   * When false, the definition is admin-only and never exposed in the Store API. Defaults to false
   * on create; an update without it keeps the stored value.
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
