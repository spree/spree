import type { PurchaseOrder } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { Badge, RelativeTime, ResourceNameCell, StatusBadge } from '@spree/dashboard-ui'
import { TruckIcon } from '@spree/dashboard-ui/icons'
import i18n from 'i18next'
import { supplierAutocompleteProps } from '../hooks/use-suppliers'
import { isClosed, PURCHASE_ORDER_STATUSES } from '../schemas/inventory-operations'

// A calendar day, compared as text: both sides are `yyyy-mm-dd`. Display
// only — the list filters below are answered by the server's own scopes.
function dayHasPassed(date: string | null | undefined): boolean {
  return !!date && date < new Date().toISOString().slice(0, 10)
}

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
          tone={
            po.status === 'received'
              ? 'success'
              : po.status === 'over_received'
                ? 'warning'
                : undefined
          }
        />
      ),
    },
    {
      key: 'supplier',
      label: i18n.t('admin.purchase_orders.columns.supplier'),
      filterable: true,
      // Picked from a list rather than typed, the way an order filters by its
      // customer: a merchant asking what is on order from Acme knows who they
      // mean. Matched through the association's id, so a supplier renamed
      // since the order was placed still answers.
      filterType: 'resource',
      filterResource: supplierAutocompleteProps('purchase-orders-table-supplier-filter'),
      ransackAttribute: 'supplier_id',
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
      key: 'cancel_by',
      label: i18n.t('admin.purchase_orders.columns.cancel_by'),
      sortable: true,
      filterable: true,
      filterType: 'date',
      className: 'text-sm text-muted-foreground whitespace-nowrap',
      render: (po) => po.cancel_by ?? '—',
    },
    {
      // A scope, not a predicate on `expected_at`: "is it late?" is one
      // question with two answers, which is what a boolean control needs.
      key: 'overdue',
      label: i18n.t('admin.purchase_orders.columns.overdue'),
      ransackAttribute: 'overdue',
      ransackScope: true,
      sortable: false,
      filterable: true,
      filterType: 'boolean',
      booleanLabels: {
        true: i18n.t('admin.purchase_orders.filters.overdue'),
        false: i18n.t('admin.purchase_orders.filters.not_overdue'),
      },
      quickFilter: true,
      render: (po) =>
        !isClosed(po.status) && dayHasPassed(po.expected_at) ? (
          <Badge variant="destructive">{i18n.t('admin.purchase_orders.filters.overdue')}</Badge>
        ) : (
          '—'
        ),
    },
    {
      key: 'past_cancel_by',
      label: i18n.t('admin.purchase_orders.columns.past_cancel_by'),
      ransackAttribute: 'past_cancel_by',
      ransackScope: true,
      sortable: false,
      filterable: true,
      filterType: 'boolean',
      booleanLabels: {
        true: i18n.t('admin.purchase_orders.filters.past_cancel_by'),
        false: i18n.t('admin.purchase_orders.filters.not_past_cancel_by'),
      },
      render: (po) =>
        !isClosed(po.status) && dayHasPassed(po.cancel_by) ? (
          <Badge variant="destructive">
            {i18n.t('admin.purchase_orders.filters.past_cancel_by')}
          </Badge>
        ) : (
          '—'
        ),
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
