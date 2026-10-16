// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type CustomFieldDefinitionUpdateParams = {
  /** Defaults to `custom`. */
  namespace?: string
  key?: string
  /** Human-readable name; defaults to the titleized `key`. */
  label?: string
  /**
   * Custom field type token (`short_text`, `long_text`, `rich_text`, `number`, …). An extension
   * type that has no token is named by its registered class instead.
   */
  field_type?: string
  /** Shorthand of the resource the field attaches to, from the resource types endpoint. */
  resource_type?: string
  /** When false, the definition is admin-only and never exposed in the Store API. */
  storefront_visible?: boolean
  /**
   * Include values in storefront product text search. Supported for `short_text`, `long_text` and
   * `number` fields; other types are refused.
   */
  searchable?: boolean
  /**
   * Allow storefront product listings to sort by this field (`sort=cf_{namespace}_{key}`).
   * Supported for `short_text` and `number` fields; other types are refused.
   */
  sortable?: boolean
}
