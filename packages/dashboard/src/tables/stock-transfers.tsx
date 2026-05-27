import type { StockTransfer } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { Badge, RelativeTime, ResourceNameCell } from '@spree/dashboard-ui'
import i18n from 'i18next'
import { ArrowLeftRightIcon } from 'lucide-react'

defineTable<StockTransfer>('stock-transfers', {
  title: 'Stock Transfers',
  searchParam: 'number_cont',
  searchPlaceholder: 'Search by number or reference…',
  defaultSort: { field: 'created_at', direction: 'desc' },
  emptyIcon: <ArrowLeftRightIcon className="size-8 text-muted-foreground" />,
  emptyMessage: 'No stock transfers yet',
  columns: [
    {
      key: 'number',
      label: 'Number',
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
      label: 'Direction',
      default: true,
      render: (st) =>
        st.source_location_id ? (
          <span className="text-sm">Transfer between locations</span>
        ) : (
          <Badge variant="outline">External receive</Badge>
        ),
    },
    {
      key: 'reference',
      label: 'Reference',
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
