import type { Order } from '@spree/admin-sdk'
import { Card, CardContent, CardHeader, CardTitle } from '@spree/dashboard-ui'
import { Link } from '@tanstack/react-router'
import { StoreIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import { useSeller } from '../../../hooks/use-sellers'
import { orderGroupSearch } from '../../../lib/order-group-search'

/**
 * Where this order sits in the marketplace: who sold it, and — when the
 * customer's basket spanned several sellers — that it was part of a larger
 * purchase.
 *
 * Renders nothing for an ordinary order, so a store that sells only its own
 * goods never sees it.
 */
export function MarketplaceCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const { data: seller } = useSeller(order.seller_id ?? undefined)

  if (!order.seller_id && !order.order_group_id) return null

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.orders.detail.section_seller')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-3 text-sm">
        {order.seller_id ? (
          <div className="flex items-center gap-2">
            <StoreIcon className="size-4 shrink-0 text-muted-foreground" />
            <Link
              to={'/$storeId/sellers/$sellerId' as string}
              params={{ sellerId: order.seller_id }}
              className="no-underline"
            >
              {seller?.name ?? order.seller_id}
            </Link>
          </div>
        ) : (
          <div className="flex items-center gap-2 text-muted-foreground">
            <StoreIcon className="size-4 shrink-0" />
            {t('admin.fields.order.seller.first_party')}
          </div>
        )}

        {order.order_group_id && (
          <div className="flex flex-col gap-1 border-t pt-3">
            <span>{t('admin.orders.detail.order_group_part_of')}</span>
            <span className="text-xs text-muted-foreground">
              {t('admin.orders.detail.order_group_help')}
            </span>
            <Link
              to={'/$storeId/orders' as string}
              search={orderGroupSearch(order.order_group_id)}
              className="text-sm"
            >
              {t('admin.orders.detail.order_group_view_all')}
            </Link>
          </div>
        )}
      </CardContent>
    </Card>
  )
}
