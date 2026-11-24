/**
 * Hand-written types for the translation matrix endpoints. Their payload is
 * computed per record, so it is not part of the generated type set.
 */

import type TranslationCoverage from './generated/TranslationCoverage'

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

/** How much of one locale is translated across a whole resource type. */
export type TranslationCoverageRow = TranslationCoverage['coverage'][number]

/** One record in the coverage grid, with how many of its fields are translated per locale. */
export type TranslationCoverageRecord = TranslationCoverage['records'][number]
