import { defineTable, Subject } from '@spree/dashboard-core'
import { RelativeTime, StatusBadge, TagList } from '@spree/dashboard-ui'
import { Link } from '@tanstack/react-router'
import i18n from 'i18next'
import { ShoppingCartIcon } from 'lucide-react'
import { channelAutocompleteProps } from '@/hooks/use-channels'

/**
 * Localized label for an order status code, resolved from the given namespace
 * (`payment_statuses`, `fulfillment_statuses`, `statuses`) with the humanized
 * code as a fallback for any value without a translation.
 */
function statusLabel(namespace: string, status: string): string {
  const key = `admin.orders.${namespace}.${status}`
  return i18n.exists(key) ? i18n.t(key) : status.replace(/_/g, ' ')
}

defineTable('orders', {
  title: i18n.t('admin.nav.orders'),
  searchParam: 'multi_search',
  searchPlaceholder: i18n.t('admin.orders.table.search_placeholder'),
  defaultSort: { field: 'completed_at', direction: 'desc' },
  emptyIcon: <ShoppingCartIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.orders.table.empty'),
  columns: [
    {
      key: 'number',
      label: i18n.t('admin.orders.columns.number'),
      sortable: true,
      filterable: true,
      default: true,
      render: (order) => (
        <Link
          to={'/$storeId/orders/$orderId' as string}
          params={{ orderId: order.id }}
          className="font-medium text-foreground no-underline"
        >
          #{order.number}
        </Link>
      ),
    },
    {
      key: 'completed_at',
      label: i18n.t('admin.orders.columns.date'),
      sortable: true,
      default: true,
      filterType: 'date',
      className: 'text-sm text-muted-foreground whitespace-nowrap',
      render: (order) => <RelativeTime iso={order.completed_at} />,
    },
    {
      key: 'email',
      label: i18n.t('admin.orders.columns.customer'),
      sortable: true,
      filterable: true,
      default: true,
      className: 'text-sm',
      render: (order) => order.email ?? '—',
    },
    {
      key: 'channel',
      label: i18n.t('admin.fields.order.channel.label'),
      sortable: true,
      filterable: true,
      filterType: 'resource',
      filterResource: channelAutocompleteProps('orders-table-channel-filter'),
      ransackAttribute: 'channel_id',
      default: true,
      className: 'text-sm text-muted-foreground',
      render: (order) => order.channel?.name ?? '—',
    },
    {
      key: 'payment_status',
      label: i18n.t('admin.orders.columns.payment'),
      sortable: true,
      filterable: true,
      default: true,
      filterType: 'enum',
      filterOptions: [
        { value: 'balance_due', label: i18n.t('admin.orders.payment_statuses.balance_due') },
        { value: 'credit_owed', label: i18n.t('admin.orders.payment_statuses.credit_owed') },
        { value: 'failed', label: i18n.t('admin.orders.payment_statuses.failed') },
        { value: 'paid', label: i18n.t('admin.orders.payment_statuses.paid') },
        { value: 'void', label: i18n.t('admin.orders.payment_statuses.void') },
      ],
      render: (order) =>
        order.payment_status ? (
          <StatusBadge
            status={order.payment_status}
            label={statusLabel('payment_statuses', order.payment_status)}
          />
        ) : (
          '—'
        ),
    },
    {
      key: 'fulfillment_status',
      label: i18n.t('admin.orders.columns.fulfillment'),
      sortable: true,
      filterable: true,
      default: true,
      filterType: 'enum',
      filterOptions: [
        { value: 'backorder', label: i18n.t('admin.orders.fulfillment_statuses.backorder') },
        { value: 'canceled', label: i18n.t('admin.orders.fulfillment_statuses.canceled') },
        { value: 'partial', label: i18n.t('admin.orders.fulfillment_statuses.partial') },
        { value: 'pending', label: i18n.t('admin.orders.fulfillment_statuses.pending') },
        { value: 'ready', label: i18n.t('admin.orders.fulfillment_statuses.ready') },
        { value: 'fulfilled', label: i18n.t('admin.orders.fulfillment_statuses.fulfilled') },
      ],
      render: (order) =>
        order.fulfillment_status ? (
          <StatusBadge
            status={order.fulfillment_status}
            label={statusLabel('fulfillment_statuses', order.fulfillment_status)}
          />
        ) : (
          '—'
        ),
    },
    {
      key: 'total_quantity',
      label: i18n.t('admin.orders.columns.items'),
      sortable: true,
      default: true,
      className: 'text-right tabular-nums text-sm text-muted-foreground',
      render: (order) => {
        const count = order.total_quantity ?? 0
        return i18n.t('admin.orders.item_count', { count })
      },
    },
    {
      key: 'total',
      label: i18n.t('admin.fields.total.label'),
      sortable: true,
      filterable: true,
      default: true,
      filterType: 'number',
      className: 'text-right tabular-nums whitespace-nowrap font-medium',
      render: (order) => order.display_total ?? '—',
    },
    {
      key: 'currency',
      label: i18n.t('admin.fields.currency.label'),
      sortable: true,
      filterable: true,
      filterType: 'currency',
      default: false,
      render: (order) => order.currency ?? '—',
    },
    {
      key: 'status',
      label: i18n.t('admin.fields.status.label'),
      sortable: true,
      filterable: true,
      default: false,
      filterType: 'enum',
      filterOptions: [
        { value: 'draft', label: i18n.t('admin.orders.statuses.draft') },
        { value: 'placed', label: i18n.t('admin.orders.statuses.placed') },
        { value: 'canceled', label: i18n.t('admin.orders.statuses.canceled') },
      ],
      render: (order) => (
        <StatusBadge status={order.status} label={statusLabel('statuses', order.status)} />
      ),
    },
    {
      key: 'tags',
      label: i18n.t('admin.orders.columns.tags'),
      sortable: false,
      filterable: true,
      filterType: 'tags',
      taggableType: Subject.Order,
      default: false,
      render: (order) => <TagList tags={order.tags} />,
    },
    // Filter-only columns
    {
      key: 'first_name',
      label: i18n.t('admin.fields.first_name.label'),
      filterable: true,
      displayable: false,
      ransackAttribute: 'bill_address_firstname_i',
    },
    {
      key: 'last_name',
      label: i18n.t('admin.fields.last_name.label'),
      filterable: true,
      displayable: false,
      ransackAttribute: 'bill_address_lastname',
    },
    {
      key: 'sku',
      label: i18n.t('admin.orders.columns.sku'),
      filterable: true,
      displayable: false,
      ransackAttribute: 'line_items_variant_sku',
    },
  ],
})
