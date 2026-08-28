import i18n from 'i18next'

/**
 * The API's type shorthand (`products`), which keys the per-type translations
 * (`admin.imports.types.<key>`).
 *
 * Shorthand values pass through unchanged; the demodulizing is a fallback for
 * `Spree::Imports::Products`-style values from an older server or a payload
 * cached before the shorthand landed.
 */
export function importTypeKey(type: string | null): string {
  return (
    (type ?? '')
      .split('::')
      .pop()
      ?.replace(/([a-z])([A-Z])/g, '$1_$2')
      .toLowerCase() ?? ''
  )
}

/** Translated display name for an import type (`admin.imports.types.<key>`). */
export function importTypeLabel(type: string | null): string {
  const key = importTypeKey(type)
  return key ? i18n.t(`admin.imports.types.${key}`, { defaultValue: key }) : ''
}
