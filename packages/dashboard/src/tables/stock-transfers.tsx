import type { StockTransfer } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { RelativeTime, ResourceNameCell, StatusBadge } from '@spree/dashboard-ui'
import { ArrowLeftRightIcon } from '@spree/dashboard-ui/icons'
import i18n from 'i18next'
import { STOCK_TRANSFER_STATUSES } from '../schemas/inventory-operations'

function statusLabel(value: string): string {
  return i18n.t(`admin.stock_transfers.statuses.${value}`)
}

defineTable<StockTransfer>('stock-transfers', {
  title: i18n.t('admin.stock_transfers.title'),
  description: i18n.t('admin.table_descriptions.stock_transfers'),
  docsPath: 'manage-products/stock-transfers',
  searchParam: 'number_or_reference_cont',
  searchPlaceholder: i18n.t('admin.stock_transfers.table.search_placeholder'),
  defaultSort: { field: 'created_at', direction: 'desc' },
  emptyIcon: <ArrowLeftRightIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.stock_transfers.table.empty'),
  columns: [
    {
      key: 'number',
      label: i18n.t('admin.stock_transfers.columns.number'),
      sortable: true,
      default: true,
      render: (st) => (
        <ResourceNameCell
          id={st.id}
          dataAttr="data-stock-transfer-id"
          name={st.number}
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
      filterOptions: STOCK_TRANSFER_STATUSES.map((value) => ({ value, label: statusLabel(value) })),
      quickFilter: true,
      default: true,
      // `received` overrides the shared tone map, which reads that code as a
      // return still owing a refund. A finished transfer is not amber.
      render: (st) => (
        <StatusBadge
          status={st.status}
          label={statusLabel(st.status)}
          tone={st.status === 'received' ? 'success' : undefined}
        />
      ),
    },
    {
      key: 'reference',
      label: i18n.t('admin.stock_transfers.columns.reference'),
      default: true,
      render: (st) => st.reference ?? '—',
    },
    {
      key: 'quantity',
      label: i18n.t('admin.stock_transfers.columns.units'),
      default: true,
      className: 'tabular-nums',
      // Received against shipped: the one number that says whether the trip is
      // still owed anything.
      render: (st) => `${st.quantity_received_total} / ${st.quantity_shipped_total}`,
    },
    {
      key: 'shipped_at',
      label: i18n.t('admin.stock_transfers.columns.shipped'),
      sortable: true,
      default: true,
      className: 'text-sm text-muted-foreground whitespace-nowrap',
      render: (st) => (st.shipped_at ? <RelativeTime iso={st.shipped_at} /> : '—'),
    },
    {
      key: 'created_at',
      label: i18n.t('admin.fields.created_at.label'),
      sortable: true,
      filterable: true,
      filterType: 'date',
      className: 'text-sm text-muted-foreground whitespace-nowrap',
      render: (st) => <RelativeTime iso={st.created_at} />,
    },
  ],
})
