import type { LineItem } from '@spree/admin-sdk'
import { useStore } from '@spree/dashboard-core'
import { Link } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'

/**
 * Which agreement priced this line, as a link to it. Read off the price list
 * the line was stamped with, never resolved again — editing a catalog must
 * not rewrite what an order says it was charged from. Renders nothing for a
 * shop-price or hand-negotiated line.
 */
export function LineItemPriceSource({ lineItem }: { lineItem: LineItem }) {
  const { t } = useTranslation()
  const { storeId } = useStore()

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
  }

  if (lineItem.price_list_id) {
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
  }

  return null
}
