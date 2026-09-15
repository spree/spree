import { defineTable, formatStoreDateTime } from '@spree/dashboard-core'
import { ResourceNameCell, StatusBadge } from '@spree/dashboard-ui'
import { HandCoinsIcon } from '@spree/dashboard-ui/icons'
import type { Payout } from '@spree/seller-sdk'
import i18n from 'i18next'
import { useStoreTimezone } from '../hooks/use-store-timezone'

/**
 * A ledger row's date in the marketplace's timezone.
 *
 * Its own component because a table definition is module-level and has no
 * access to hooks, while `render` is called inside the table's JSX — so a
 * cell may use them like any other component.
 */
function LedgerDate({ iso }: { iso: string }) {
  const timezone = useStoreTimezone()

  return <>{formatStoreDateTime(iso, timezone)}</>
}

const STATUSES = ['pending', 'processing', 'completed', 'failed', 'unresolved'] as const

defineTable<Payout>('seller-payouts', {
  title: i18n.t('payouts.title'),
  searchParam: 'reference_cont',
  searchPlaceholder: i18n.t('payouts.search_placeholder'),
  defaultSort: { field: 'created_at', direction: 'desc' },
  emptyIcon: <HandCoinsIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('payouts.empty'),
  columns: [
    {
      key: 'created_at',
      label: i18n.t('payouts.columns.date'),
      sortable: true,
      filterable: true,
      filterType: 'date',
      quickFilter: true,
      default: true,
      render: (payout) => (
        <ResourceNameCell
          id={payout.id}
          dataAttr="data-payout-id"
          name={<LedgerDate iso={payout.created_at} />}
        />
      ),
    },
    {
      key: 'status',
      label: i18n.t('payouts.columns.status'),
      sortable: true,
      filterable: true,
      filterType: 'enum',
      filterOptions: STATUSES.map((status) => ({
        value: status,
        label: i18n.t(`earnings.statuses.${status}`),
      })),
      quickFilter: true,
      default: true,
      render: (payout) => (
        <StatusBadge
          status={payout.status}
          label={i18n.t(`earnings.statuses.${payout.status}`, { defaultValue: payout.status })}
        />
      ),
    },
    {
      key: 'transfers_count',
      label: i18n.t('payouts.columns.earnings'),
      default: true,
      render: (payout) => payout.transfers_count,
    },
    {
      key: 'reference',
      label: i18n.t('payouts.columns.reference'),
      default: true,
      render: (payout) => payout.reference ?? '—',
    },
    {
      key: 'amount',
      label: i18n.t('payouts.columns.amount'),
      sortable: true,
      default: true,
      className: 'text-right tabular-nums',
      render: (payout) => payout.display_amount,
    },
  ],
})
