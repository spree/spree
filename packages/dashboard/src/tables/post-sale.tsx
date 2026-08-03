import type { Claim, Exchange, Return } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { Badge, RelativeTime, ResourceNameCell } from '@spree/dashboard-ui'
import i18n from 'i18next'
import { RepeatIcon, RotateCcwIcon, ShieldAlertIcon } from 'lucide-react'

/**
 * Status colours read the same way across all three: amber while the merchant
 * still owes an action, green once settled, muted when it went nowhere.
 */
const STATUS_VARIANT: Record<
  string,
  'success' | 'destructive' | 'secondary' | 'default' | 'outline'
> = {
  requested: 'default',
  open: 'default',
  approved: 'default',
  received: 'default',
  refunded: 'success',
  fulfilled: 'success',
  resolved: 'success',
  denied: 'destructive',
  canceled: 'secondary',
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
    default: true,
    render: (record: { status: string }) => (
      <Badge variant={STATUS_VARIANT[record.status] ?? 'secondary'}>
        {statusLabel(record.status)}
      </Badge>
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
      render: (r) => <ResourceNameCell id={r.id} dataAttr="data-return-id" name={r.number} />,
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
      render: (e) => <ResourceNameCell id={e.id} dataAttr="data-exchange-id" name={e.number} />,
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
      render: (c) => <ResourceNameCell id={c.id} dataAttr="data-claim-id" name={c.number} />,
    },
    statusColumn(['open', 'approved', 'resolved', 'denied', 'canceled']),
    {
      key: 'claim_type',
      label: i18n.t('admin.pages.orders.detail.claims.claim_type'),
      sortable: true,
      filterable: true,
      default: true,
      render: (c) => (
        <Badge variant="outline">
          {i18n.t(`admin.pages.orders.detail.claims.types.${c.claim_type}`, {
            defaultValue: c.claim_type,
          })}
        </Badge>
      ),
    },
    orderColumn<Claim>(),
    createdColumn<Claim>(),
  ],
})
