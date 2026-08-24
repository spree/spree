import type { Customer, Order } from '@spree/admin-sdk'
import {
  Badge,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  RelativeTime,
  StatusBadge,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@spree/dashboard-ui'
import { Link } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'

export function CustomerOrdersCard({
  customer,
  orders,
  totalCount,
  isLoading,
}: {
  customer: Customer
  orders: Order[]
  totalCount: number
  isLoading: boolean
}) {
  const { t } = useTranslation()
  if (isLoading) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>{t('admin.pages.customers.detail.section_orders')}</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-muted-foreground">{t('admin.common.loading')}</p>
        </CardContent>
      </Card>
    )
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>
          {t('admin.pages.customers.detail.section_orders')}
          {totalCount > 0 && <Badge variant="outline">{totalCount}</Badge>}
        </CardTitle>
        {totalCount > orders.length && (
          <CardAction>
            <Link
              to={'/$storeId/orders' as string}
              search={{
                filters: [{ id: '1', field: 'user_id_eq', operator: 'eq', value: customer.id }],
              }}
              className="text-sm text-primary hover:underline"
            >
              {t('admin.actions.view_all')} →
            </Link>
          </CardAction>
        )}
      </CardHeader>
      {orders.length === 0 ? (
        <CardContent>
          <p className="text-sm text-muted-foreground">
            {t('admin.pages.customers.detail.orders_empty')}
          </p>
        </CardContent>
      ) : (
        <CardContent className="p-0">
          <Table roundedBottom>
            <TableHeader>
              <TableRow>
                <TableHead>{t('admin.customers.detail.orders_table.order')}</TableHead>
                <TableHead>{t('admin.customers.detail.orders_table.date')}</TableHead>
                <TableHead>{t('admin.fields.status.label')}</TableHead>
                <TableHead className="text-right">{t('admin.fields.total.label')}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {orders.map((order: Order) => (
                <TableRow key={order.id}>
                  <TableCell>
                    <Link
                      to={'/$storeId/orders/$orderId' as string}
                      params={{ orderId: order.id }}
                      className="font-medium text-foreground no-underline"
                    >
                      #{order.number}
                    </Link>
                  </TableCell>
                  <TableCell className="text-muted-foreground">
                    <RelativeTime iso={order.completed_at ?? order.created_at} />
                  </TableCell>
                  <TableCell>
                    <span className="inline-flex gap-1">
                      <StatusBadge status={order.status} />
                      {order.payment_status && <StatusBadge status={order.payment_status} />}
                      {order.fulfillment_status && (
                        <StatusBadge status={order.fulfillment_status} />
                      )}
                    </span>
                  </TableCell>
                  <TableCell className="text-right font-medium tabular-nums">
                    {order.display_total}
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </CardContent>
      )}
    </Card>
  )
}
