import type { PurchaseOrder } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { RelativeTime, ResourceNameCell, StatusBadge } from '@spree/dashboard-ui'
import { TruckIcon } from '@spree/dashboard-ui/icons'
import i18n from 'i18next'
import { PURCHASE_ORDER_STATUSES } from '../schemas/inventory-operations'

function statusLabel(value: string): string {
  return i18n.t(`admin.purchase_orders.statuses.${value}`)
}

defineTable<PurchaseOrder>('purchase-orders', {
  title: i18n.t('admin.purchase_orders.title'),
  description: i18n.t('admin.table_descriptions.purchase_orders'),
  searchParam: 'number_or_reference_cont',
  searchPlaceholder: i18n.t('admin.purchase_orders.table.search_placeholder'),
  defaultSort: { field: 'created_at', direction: 'desc' },
  emptyIcon: <TruckIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.purchase_orders.table.empty'),
  columns: [
    {
      key: 'number',
      label: i18n.t('admin.purchase_orders.columns.number'),
      sortable: true,
      default: true,
      render: (po) => (
        <ResourceNameCell
          id={po.id}
          dataAttr="data-purchase-order-id"
          name={po.number}
          nameClassName="tabular-nums"
        />
      ),
    },
    {
      key: 'status',
      label: i18n.t('admin.fields.status.label'),
      sortable: true,
      filterable: true,
      filterType: 'enum',
      filterOptions: PURCHASE_ORDER_STATUSES.map((value) => ({ value, label: statusLabel(value) })),
      quickFilter: true,
      default: true,
      // `received` overrides the shared tone map, which reads that code as a
      // return still owing a refund. A finished transfer is not amber.
      render: (po) => (
        <StatusBadge
          status={po.status}
          label={statusLabel(po.status)}
          tone={po.status === 'received' ? 'success' : undefined}
        />
      ),
    },
    {
      key: 'supplier',
      label: i18n.t('admin.purchase_orders.columns.supplier'),
      default: true,
      render: (po) => po.supplier?.name ?? '—',
    },
    {
      key: 'quantity',
      label: i18n.t('admin.purchase_orders.columns.units'),
      default: true,
      className: 'tabular-nums',
      render: (po) => `${po.quantity_received_total} / ${po.quantity_ordered_total}`,
    },
    {
      key: 'display_subtotal',
      label: i18n.t('admin.purchase_orders.columns.subtotal'),
      default: true,
      className: 'tabular-nums',
      render: (po) => po.display_subtotal,
    },
    {
      key: 'expected_at',
      label: i18n.t('admin.purchase_orders.columns.expected'),
      sortable: true,
      filterable: true,
      filterType: 'date',
      default: true,
      className: 'text-sm text-muted-foreground whitespace-nowrap',
      render: (po) => po.expected_at ?? '—',
    },
    {
      key: 'created_at',
      label: i18n.t('admin.fields.created_at.label'),
      sortable: true,
      filterable: true,
      filterType: 'date',
      className: 'text-sm text-muted-foreground whitespace-nowrap',
      render: (po) => <RelativeTime iso={po.created_at} />,
    },
  ],
})
