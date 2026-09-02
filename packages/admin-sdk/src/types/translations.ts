/**
 * Hand-written types for the translation management endpoints. These are
 * controller-shaped responses (not Alba serializer output), so they are not
 * part of the generated type set.
 */

/** Content kind of a translatable field, driving generic editor rendering. */
export type TranslatableFieldType = 'string' | 'html'

/** A translatable field with its source (default-locale) value. */
export interface TranslatableField {
  key: string
  type: TranslatableFieldType
  source: string | null
}

/**
 * Translated values for one locale: a map of field key to value, plus a
 * computed completeness counter. A field absent or null has no translation.
 */
export interface LocaleTranslations {
  translated_field_count: number
  [field: string]: string | number | null
}

/** Full translation matrix for a single resource (the dedicated endpoint). */
export interface ResourceTranslations {
  resource_type: string
  resource_id: string
  default_locale: string
  supported_locales: string[]
  fields: TranslatableField[]
  translations: Record<string, LocaleTranslations>
  /**
   * Translatable child records nested under the parent (e.g. an option type
   * carries its option values), so an editor fetches both in one read. Writes
   * stay flat via the batch endpoint.
   */
  children?: ResourceTranslationsNode[]
}

/** A nested translation node (parent or child) — same shape minus locale meta. */
export interface ResourceTranslationsNode {
  resource_type: string
  resource_id: string
  fields: TranslatableField[]
  translations: Record<string, LocaleTranslations>
  children?: ResourceTranslationsNode[]
}

/** Upsert payload: locale => { field => value }. null deletes a cell. */
export type TranslationsUpsertParams = Record<string, Record<string, string | null>>

/** One entry in a batch translation upsert. */
export interface TranslationBatchEntry {
  resource_type: string
  resource_id: string
  values: TranslationsUpsertParams
}

/** A supported locale as returned by `GET /admin/locales`. */
export interface Locale {
  code: string
  name: string
  default: boolean
  rtl: boolean
}

/** A translatable resource entry from `GET /admin/translatable_resources`. */
export interface TranslatableResource {
  resource_type: string
  fields: Array<{ key: string; type: TranslatableFieldType }>
  /**
   * Whether this resource has a dedicated `…/:id/translations` read route.
   * When `false` it is still writable via the batch endpoint and readable
   * inline (e.g. option values are returned as children of an option type) —
   * don't request a standalone matrix for it.
   */
  readable: boolean
}

/** How much of one locale is translated across a whole resource type. */
export interface TranslationCoverageRow {
  locale: string
  translated: number
  total: number
  /** Fraction between 0 and 1. */
  coverage: number
}

/**
 * One record in the coverage grid. `locales` maps each locale to how many of
 * the record's translatable fields are filled in — compare against
 * `field_count` to tell complete from partial.
 */
export interface TranslationCoverageRecord {
  id: string
  label: string | null
  locales: Record<string, number>
}

/** Response of `GET /admin/translations?resource_type=…`. */
export interface TranslationCoverage {
  resource_type: string
  default_locale: string
  locales: string[]
  /** How many translatable fields a record of this type has. */
  field_count: number
  coverage: TranslationCoverageRow[]
  records: TranslationCoverageRecord[]
}
