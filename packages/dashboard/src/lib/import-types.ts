import i18n from 'i18next'

/** Statuses the wizard polls through — row creation and processing. */
const ACTIVE_STATUSES = new Set(['completed_mapping', 'processing'])

export function isImportActive(status: string | undefined): boolean {
  return !!status && ACTIVE_STATUSES.has(status)
}

/**
 * `Spree::Imports::Products` → `products`. Keys the per-type translations
 * (`admin.imports.types.<key>`) and the post-import destination below.
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
