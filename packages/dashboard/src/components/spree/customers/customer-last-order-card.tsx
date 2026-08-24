import type { Order } from '@spree/admin-sdk'
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  RelativeTime,
  StatusBadge,
  Thumbnail,
} from '@spree/dashboard-ui'
import { Link } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'

export function CustomerLastOrderCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.customers.detail.last_order_placed')}</CardTitle>
      </CardHeader>
      <CardContent className="p-0">
        <div className="border-t flex items-center justify-between px-6 py-3">
          <div>
            <Link
              to={'/$storeId/orders/$orderId' as string}
              params={{ orderId: order.id }}
              className="font-medium text-foreground no-underline"
            >
              #{order.number}
            </Link>
            <span className="ml-2 inline-flex gap-2">
              {order.payment_status && <StatusBadge status={order.payment_status} />}
              {order.fulfillment_status && <StatusBadge status={order.fulfillment_status} />}
            </span>
            {order.completed_at && (
              <div className="text-xs text-muted-foreground mt-1">
                <RelativeTime iso={order.completed_at} />
              </div>
            )}
          </div>
          <div className="font-semibold">{order.display_total}</div>
        </div>
        {order.items?.slice(0, 5).map((item) => (
          <div key={item.id} className="border-t flex items-center gap-3 px-6 py-3 text-sm">
            <Thumbnail src={item.thumbnail_url} />
            <div className="flex-1 min-w-0">
              <div className="truncate">{item.name}</div>
              {item.options_text && (
                <div className="text-xs text-muted-foreground truncate">{item.options_text}</div>
              )}
            </div>
            <div className="text-muted-foreground">×{item.quantity}</div>
            <div className="font-medium tabular-nums">{item.display_total}</div>
          </div>
        ))}
      </CardContent>
    </Card>
  )
}
