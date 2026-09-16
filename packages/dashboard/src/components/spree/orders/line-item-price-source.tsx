import type { LineItem } from '@spree/admin-sdk'
import { useStore } from '@spree/dashboard-core'
import { Link } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'

/**
 * Which agreement priced this line, as a link to it. The price list is the
 * one stamped on the line, never re-resolved; the catalog is that list's
 * current owner.
 */
export function LineItemPriceSource({ lineItem }: { lineItem: LineItem }) {
  const { t } = useTranslation()
  const { storeId } = useStore()

  // A list a catalog owns is the catalog, a standalone list stands for
  // itself, and a shop-price or hand-negotiated line has nothing to point at.
  if (lineItem.catalog_id) {
    return (
      <Link
        to="/$storeId/products/catalogs/$catalogId"
        params={{ storeId, catalogId: lineItem.catalog_id }}
        className="hover:text-foreground hover:underline"
      >
        {t('admin.orders.detail.priced_by', {
          name: lineItem.catalog_name ?? lineItem.catalog_id,
        })}
      </Link>
    )
  } else if (lineItem.price_list_id) {
    return (
      <Link
        to="/$storeId/products/price-lists/$priceListId"
        params={{ storeId, priceListId: lineItem.price_list_id }}
        className="hover:text-foreground hover:underline"
      >
        {t('admin.orders.detail.priced_by', {
          name: lineItem.price_list_name ?? lineItem.price_list_id,
        })}
      </Link>
    )
  } else {
    return null
  }
}
