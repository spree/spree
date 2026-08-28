import { importTypeKey } from '@spree/dashboard-core'

export { importTypeKey, importTypeLabel, isImportActive } from '@spree/dashboard-core'

/**
 * Resource index the "Done" action points to after a finished import.
 *
 * Stays in the app rather than the framework: the route it names belongs to
 * this dashboard's own tree, and the seller panel files its catalog elsewhere.
 */
export function importTypeIndexPath(type: string | null): string {
  switch (importTypeKey(type)) {
    case 'customers':
      return '/$storeId/customers'
    default:
      return '/$storeId/products'
  }
}
