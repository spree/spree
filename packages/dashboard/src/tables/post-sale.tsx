import type { Claim, Exchange, Return } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { RelativeTime, StatusBadge } from '@spree/dashboard-ui'
import { RepeatIcon, RotateCcwIcon, ShieldAlertIcon } from '@spree/dashboard-ui/icons'
import { Link } from '@tanstack/react-router'
import i18n from 'i18next'

/**
 * The record's own number, linking to the order it belongs to — that page is
 * where it can actually be actioned, so there is nowhere else useful to go.
 */
function numberCell(record: { number: string; order_id?: string | null }) {
  if (!record.order_id) return record.number

  return (
    <Link
      to={'/$storeId/orders/$orderId' as string}
      params={{ orderId: record.order_id }}
      className="font-medium text-foreground no-underline"
    >
      {record.number}
    </Link>
  )
}

function statusLabel(value: string): string {
  const key = `admin.post_sale.statuses.${value}`
  return i18n.exists(key)
    ? i18n.t(key)
    : value.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase())
}

function statusColumn(values: string[]) {
  return {
    key: 'status',
    label: i18n.t('admin.fields.status.label'),
    sortable: true,
    filterable: true,
    filterType: 'enum' as const,
    filterOptions: values.map((value) => ({ value, label: statusLabel(value) })),
    quickFilter: true,
    default: true,
    render: (record: { status: string }) => (
      <StatusBadge status={record.status} label={statusLabel(record.status)} />
    ),
  }
}

function orderColumn<T extends { order?: { number?: string } | null }>() {
  return {
    key: 'order',
    label: i18n.t('admin.nav.orders'),
    default: true,
    render: (record: T) => record.order?.number ?? '—',
  }
}

function createdColumn<T extends { created_at: string }>() {
  return {
    key: 'created_at',
    label: i18n.t('admin.fields.created_at.label'),
    sortable: true,
    default: true,
    render: (record: T) => <RelativeTime iso={record.created_at} />,
  }
}

defineTable<Return>('returns', {
  title: i18n.t('admin.nav.returns'),
  searchParam: 'number_cont',
  searchPlaceholder: i18n.t('admin.post_sale.search_placeholder'),
  defaultSort: { field: 'created_at', direction: 'desc' },
  emptyIcon: <RotateCcwIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.post_sale.returns_empty'),
  columns: [
    {
      key: 'number',
      label: i18n.t('admin.fields.number.label'),
      sortable: true,
      filterable: true,
      default: true,
      render: (r) => numberCell(r),
    },
    statusColumn(['requested', 'approved', 'received', 'refunded', 'canceled']),
    orderColumn<Return>(),
    {
      key: 'display_refund_total',
      label: i18n.t('admin.pages.orders.detail.returns.refund_total'),
      default: true,
      className: 'text-right tabular-nums whitespace-nowrap font-medium',
      render: (r) => r.display_refund_total,
    },
    createdColumn<Return>(),
  ],
})

defineTable<Exchange>('exchanges', {
  title: i18n.t('admin.nav.exchanges'),
  searchParam: 'number_cont',
  searchPlaceholder: i18n.t('admin.post_sale.search_placeholder'),
  defaultSort: { field: 'created_at', direction: 'desc' },
  emptyIcon: <RepeatIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.post_sale.exchanges_empty'),
  columns: [
    {
      key: 'number',
      label: i18n.t('admin.fields.number.label'),
      sortable: true,
      filterable: true,
      default: true,
      render: (e) => numberCell(e),
    },
    statusColumn(['requested', 'approved', 'received', 'fulfilled', 'canceled']),
    orderColumn<Exchange>(),
    {
      key: 'display_price_difference',
      label: i18n.t('admin.pages.orders.detail.exchanges.price_difference'),
      default: true,
      className: 'text-right tabular-nums whitespace-nowrap font-medium',
      render: (e) => e.display_price_difference,
    },
    createdColumn<Exchange>(),
  ],
})

defineTable<Claim>('claims', {
  title: i18n.t('admin.nav.claims'),
  searchParam: 'number_cont',
  searchPlaceholder: i18n.t('admin.post_sale.search_placeholder'),
  defaultSort: { field: 'created_at', direction: 'desc' },
  emptyIcon: <ShieldAlertIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.post_sale.claims_empty'),
  columns: [
    {
      key: 'number',
      label: i18n.t('admin.fields.number.label'),
      sortable: true,
      filterable: true,
      default: true,
      render: (c) => numberCell(c),
    },
    statusColumn(['open', 'approved', 'resolved', 'denied', 'canceled']),
    orderColumn<Claim>(),
    createdColumn<Claim>(),
  ],
})
