import { defineTable } from '@spree/dashboard-core'
import { ResourceNameCell, StatusBadge } from '@spree/dashboard-ui'
import { PackageIcon } from '@spree/dashboard-ui/icons'
import type { Order } from '@spree/seller-sdk'
import i18n from 'i18next'

/** Mirrors the operator dashboard's order status vocabularies. */
const FULFILLMENT_STATUSES = [
  'unfulfilled',
  'backorder',
  'partial',
  'fulfilled',
  'delivered',
  'canceled',
] as const
const PAYMENT_STATUSES = [
  'none',
  'authorized',
  'partially_paid',
  'paid',
  'partially_refunded',
  'refunded',
  'overcharged',
  'voided',
] as const

defineTable<Order>('seller-orders', {
  title: i18n.t('orders.title'),
  description: i18n.t('orders.description'),
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
      filterable: true,
      filterType: 'date',
      quickFilter: true,
      default: true,
      render: (order) =>
        order.completed_at ? new Date(order.completed_at).toLocaleDateString() : '—',
    },
    {
      key: 'fulfillment_status',
      label: i18n.t('orders.columns.fulfillment'),
      filterable: true,
      filterType: 'enum',
      filterOptions: FULFILLMENT_STATUSES.map((status) => ({
        value: status,
        label: i18n.t(`orders.fulfillment_statuses.${status}`),
      })),
      quickFilter: true,
      default: true,
      render: (order) =>
        order.fulfillment_status ? (
          <StatusBadge
            status={order.fulfillment_status}
            label={i18n.t(`orders.fulfillment_statuses.${order.fulfillment_status}`)}
          />
        ) : (
          '—'
        ),
    },
    {
      key: 'payment_status',
      label: i18n.t('orders.columns.payment'),
      filterable: true,
      filterType: 'enum',
      filterOptions: PAYMENT_STATUSES.map((status) => ({
        value: status,
        label: i18n.t(`orders.payment_statuses.${status}`),
      })),
      quickFilter: true,
      default: true,
      render: (order) =>
        order.payment_status ? (
          <StatusBadge
            status={order.payment_status}
            label={i18n.t(`orders.payment_statuses.${order.payment_status}`)}
          />
        ) : (
          '—'
        ),
    },
    {
      key: 'total',
      label: i18n.t('orders.columns.total'),
      default: true,
      render: (order) => order.display_total as string,
    },
  ],
})
