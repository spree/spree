import { importTypeKey, type PanelImport } from '@spree/dashboard-core'

export { importTypeKey, importTypeLabel, isImportActive } from '@spree/dashboard-core'

/**
 * Where "View records" goes after a finished import.
 *
 * Stays in the app rather than the framework: the routes it names belong to
 * this dashboard's own tree, and the seller panel files its catalog elsewhere.
 * A price-list import points at the list it wrote into rather than an index,
 * since the rows it produced live nowhere else.
 */
export function importTypeDestination(
  type: string | null,
  imp?: PanelImport,
): { to: string; params?: Record<string, string> } {
  switch (importTypeKey(type)) {
    case 'customers':
      return { to: '/$storeId/customers' }
    case 'price_list_prices':
      return imp?.price_list_id
        ? {
            to: '/$storeId/products/price-lists/$priceListId',
            params: { priceListId: imp.price_list_id },
          }
        : { to: '/$storeId/products/price-lists' }
    default:
      return { to: '/$storeId/products' }
  }
}
