import type { SellerPayout, SellerTransfer } from '@spree/admin-sdk'
import { defineTable, formatStoreDateTime, useStore } from '@spree/dashboard-core'
import { ResourceNameCell, StatusBadge } from '@spree/dashboard-ui'
import { BanknoteIcon, HandCoinsIcon } from '@spree/dashboard-ui/icons'
import { Link } from '@tanstack/react-router'
import i18n from 'i18next'
import { sellerAutocompleteProps } from '../hooks/use-sellers'

/**
 * A ledger row's date in the store's timezone.
 *
 * Its own component because a table definition is module-level and has no
 * store context, while `render` is called inside the table's JSX — so a cell
 * may use hooks like any other component.
 */
function LedgerDate({ iso }: { iso: string }) {
  const { timezone } = useStore()

  return <>{formatStoreDateTime(iso, timezone)}</>
}

const LEDGER_STATUSES = ['pending', 'processing', 'completed', 'failed', 'unresolved'] as const
const TRANSFER_KINDS = ['earning', 'refund_reversal'] as const

function statusOptions() {
  return LEDGER_STATUSES.map((status) => ({
    value: status,
    label: i18n.t(`admin.payouts.statuses.${status}`),
  }))
}

defineTable<SellerTransfer>('seller-transfers', {
  title: i18n.t('admin.nav.seller_transfers'),
  description: i18n.t('admin.payouts.transfers_description'),
  // The provider's own id for the movement. Without a searchParam the toolbar
  // would send `name_cont`, which neither ledger model whitelists — and
  // Ransack ignores an unknown condition, so the box would silently return
  // the unfiltered list.
  searchParam: 'reference_cont',
  searchPlaceholder: i18n.t('admin.payouts.search_placeholder'),
  defaultSort: { field: 'created_at', direction: 'desc' },
  emptyIcon: <BanknoteIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.payouts.transfers_empty'),
  columns: [
    {
      key: 'created_at',
      label: i18n.t('admin.payouts.columns.date'),
      sortable: true,
      filterable: true,
      filterType: 'date',
      quickFilter: true,
      default: true,
      render: (transfer) => <LedgerDate iso={transfer.created_at} />,
    },
    {
      key: 'seller_name',
      label: i18n.t('admin.nav.sellers'),
      filterable: true,
      filterType: 'resource',
      filterResource: sellerAutocompleteProps('seller-transfers-table-seller-filter'),
      ransackAttribute: 'seller_id',
      quickFilter: true,
      default: true,
      render: (transfer) =>
        transfer.seller_id ? (
          <Link
            to={'/$storeId/sellers/$sellerId' as string}
            params={{ sellerId: transfer.seller_id }}
            className="no-underline"
          >
            {transfer.seller_name ?? transfer.seller_id}
          </Link>
        ) : (
          '—'
        ),
    },
    {
      key: 'order_number',
      label: i18n.t('admin.payouts.columns.order'),
      default: true,
      render: (transfer) =>
        transfer.order_id ? (
          <Link
            to={'/$storeId/orders/$orderId' as string}
            params={{ orderId: transfer.order_id }}
            className="no-underline"
          >
            {transfer.order_number ?? transfer.order_id}
          </Link>
        ) : (
          '—'
        ),
    },
    {
      key: 'kind',
      label: i18n.t('admin.payouts.columns.kind'),
      filterable: true,
      filterType: 'enum',
      filterOptions: TRANSFER_KINDS.map((kind) => ({
        value: kind,
        label: i18n.t(`admin.payouts.kinds.${kind}`),
      })),
      quickFilter: true,
      default: true,
      render: (transfer) =>
        i18n.t(`admin.payouts.kinds.${transfer.kind}`, { defaultValue: transfer.kind }),
    },
    {
      key: 'status',
      label: i18n.t('admin.fields.status.label'),
      sortable: true,
      filterable: true,
      filterType: 'enum',
      filterOptions: statusOptions(),
      quickFilter: true,
      default: true,
      render: (transfer) => (
        <StatusBadge
          status={transfer.status}
          label={i18n.t(`admin.payouts.statuses.${transfer.status}`, {
            defaultValue: transfer.status,
          })}
        />
      ),
    },
    {
      key: 'provider',
      label: i18n.t('admin.payouts.columns.provider'),
      sortable: true,
      filterable: true,
      render: (transfer) => transfer.provider,
    },
    {
      key: 'amount',
      label: i18n.t('admin.fields.amount.label'),
      sortable: true,
      default: true,
      className: 'text-right tabular-nums',
      render: (transfer) => transfer.display_amount,
    },
  ],
})

defineTable<SellerPayout>('seller-payouts', {
  title: i18n.t('admin.nav.seller_payouts'),
  description: i18n.t('admin.payouts.payouts_description'),
  searchParam: 'reference_cont',
  searchPlaceholder: i18n.t('admin.payouts.search_placeholder'),
  defaultSort: { field: 'created_at', direction: 'desc' },
  emptyIcon: <HandCoinsIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.payouts.payouts_empty'),
  columns: [
    {
      key: 'created_at',
      label: i18n.t('admin.payouts.columns.date'),
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
      key: 'seller_name',
      label: i18n.t('admin.nav.sellers'),
      filterable: true,
      filterType: 'resource',
      filterResource: sellerAutocompleteProps('seller-payouts-table-seller-filter'),
      ransackAttribute: 'seller_id',
      quickFilter: true,
      default: true,
      render: (payout) =>
        payout.seller_id ? (
          <Link
            to={'/$storeId/sellers/$sellerId' as string}
            params={{ sellerId: payout.seller_id }}
            className="no-underline"
          >
            {payout.seller_name ?? payout.seller_id}
          </Link>
        ) : (
          '—'
        ),
    },
    {
      key: 'status',
      label: i18n.t('admin.fields.status.label'),
      sortable: true,
      filterable: true,
      filterType: 'enum',
      filterOptions: statusOptions(),
      quickFilter: true,
      default: true,
      render: (payout) => (
        <StatusBadge
          status={payout.status}
          label={i18n.t(`admin.payouts.statuses.${payout.status}`, { defaultValue: payout.status })}
        />
      ),
    },
    {
      key: 'transfers_count',
      label: i18n.t('admin.payouts.columns.earnings'),
      default: true,
      render: (payout) => payout.transfers_count,
    },
    {
      key: 'reference',
      label: i18n.t('admin.payouts.columns.reference'),
      filterable: true,
      default: true,
      render: (payout) => payout.reference ?? '—',
    },
    {
      key: 'amount',
      label: i18n.t('admin.fields.amount.label'),
      sortable: true,
      default: true,
      className: 'text-right tabular-nums',
      render: (payout) => payout.display_amount,
    },
  ],
})
