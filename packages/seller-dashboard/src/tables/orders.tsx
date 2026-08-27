import { defineTable } from '@spree/dashboard-core'
import { ResourceNameCell, StatusBadge } from '@spree/dashboard-ui'
import type { Order } from '@spree/seller-sdk'
import i18n from 'i18next'
import { PackageIcon } from 'lucide-react'

defineTable<Order>('seller-orders', {
  title: i18n.t('orders.title'),
  searchParam: 'number_cont',
  searchPlaceholder: i18n.t('orders.search_placeholder'),
  defaultSort: { field: 'completed_at', direction: 'desc' },
  emptyIcon: <PackageIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('orders.empty'),
  columns: [
    {
      key: 'number',
      label: i18n.t('orders.columns.number'),
      sortable: true,
      default: true,
      render: (order) => (
        <ResourceNameCell id={order.id} dataAttr="data-order-id" name={order.number} />
      ),
    },
    {
      key: 'completed_at',
      label: i18n.t('orders.columns.placed'),
      sortable: true,
      default: true,
      render: (order) =>
        order.completed_at ? new Date(order.completed_at).toLocaleDateString() : '—',
    },
    {
      key: 'fulfillment_status',
      label: i18n.t('orders.columns.fulfillment'),
      default: true,
      render: (order) =>
        order.fulfillment_status ? <StatusBadge status={order.fulfillment_status} /> : '—',
    },
    {
      key: 'payment_status',
      label: i18n.t('orders.columns.payment'),
      default: true,
      render: (order) =>
        order.payment_status ? <StatusBadge status={order.payment_status} /> : '—',
    },
    {
      key: 'total',
      label: i18n.t('orders.columns.total'),
      default: true,
      render: (order) => order.display_total as string,
    },
  ],
})
