import i18n from 'i18next'

/** Statuses the wizard polls through — row creation and processing. */
const ACTIVE_STATUSES = new Set(['completed_mapping', 'processing'])

/** Whether the import's pipeline is still running (the poll's continue predicate). */
export function isImportActive(status: string | undefined): boolean {
  return !!status && ACTIVE_STATUSES.has(status)
}

/**
 * The API's type shorthand (`products`), which keys the per-type translations
 * (`admin.imports.types.<key>`) and the post-import destination below.
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

/** Resource index the "Done" action points to after a finished import. */
export function importTypeIndexPath(type: string | null): string {
  switch (importTypeKey(type)) {
    case 'customers':
      return '/$storeId/customers'
    default:
      return '/$storeId/products'
  }
}
