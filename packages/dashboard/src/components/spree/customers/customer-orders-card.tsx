import type { Customer, Order } from '@spree/admin-sdk'
import { Money } from '@spree/dashboard-core'
import {
  Badge,
  Card,
  CardContent,
  Empty,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
  RelativeTime,
  Section,
  SectionActions,
  SectionHeader,
  SectionTitle,
  StatusBadge,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@spree/dashboard-ui'
import { InboxIcon } from '@spree/dashboard-ui/icons'
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
  return (
    <Section>
      <SectionHeader>
        <SectionTitle>
          <InboxIcon />
          {t('admin.pages.customers.detail.section_orders')}
          {!isLoading && totalCount > 0 && <Badge variant="outline">{totalCount}</Badge>}
        </SectionTitle>
        {!isLoading && totalCount > orders.length && (
          <SectionActions>
            <Link
              to={'/$storeId/orders' as string}
              search={{
                filters: [{ id: '1', field: 'customer_id', operator: 'eq', value: customer.id }],
              }}
              className="text-base text-primary hover:underline"
            >
              {t('admin.actions.view_all')} →
            </Link>
          </SectionActions>
        )}
      </SectionHeader>
      <Card>
        {isLoading ? (
          <CardContent>
            <p className="text-base text-muted-foreground">{t('admin.common.loading')}</p>
          </CardContent>
        ) : orders.length === 0 ? (
          <CardContent>
            <Empty className="p-4">
              <EmptyHeader>
                <EmptyMedia variant="icon">
                  <InboxIcon />
                </EmptyMedia>
                <EmptyTitle>{t('admin.pages.customers.detail.orders_empty')}</EmptyTitle>
              </EmptyHeader>
            </Empty>
          </CardContent>
        ) : (
          <CardContent className="p-0">
            <Table roundedTop>
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
                      <Money amount={order.total} currency={order.currency} />
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        )}
      </Card>
    </Section>
  )
}
