import type { StockTransfer } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { Badge, RelativeTime, ResourceNameCell } from '@spree/dashboard-ui'
import i18n from 'i18next'
import { ArrowLeftRightIcon } from 'lucide-react'

defineTable<StockTransfer>('stock-transfers', {
  title: i18n.t('admin.stock_transfers.title'),
  searchParam: 'number_cont',
  searchPlaceholder: i18n.t('admin.stock_transfers.table.search_placeholder'),
  defaultSort: { field: 'created_at', direction: 'desc' },
  emptyIcon: <ArrowLeftRightIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.stock_transfers.table.empty'),
  columns: [
    {
      key: 'number',
      label: i18n.t('admin.stock_transfers.columns.number'),
      sortable: true,
      filterable: true,
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
      key: 'source_destination',
      label: i18n.t('admin.stock_transfers.columns.direction'),
      default: true,
      render: (st) =>
        st.source_location_id ? (
          <span className="text-sm">{i18n.t('admin.stock_transfers.direction.internal')}</span>
        ) : (
          <Badge variant="outline">
            {i18n.t('admin.stock_transfers.direction.external_receive')}
          </Badge>
        ),
    },
    {
      key: 'reference',
      label: i18n.t('admin.stock_transfers.columns.reference'),
      filterable: true,
      default: true,
      render: (st) => st.reference ?? '—',
    },
    {
      key: 'created_at',
      label: i18n.t('admin.fields.created_at.label'),
      sortable: true,
      default: true,
      filterType: 'date',
      className: 'text-sm text-muted-foreground whitespace-nowrap',
      render: (st) => <RelativeTime iso={st.created_at} />,
    },
  ],
})
