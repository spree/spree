import { defineTable, formatStoreDateTime, useTenantId } from '@spree/dashboard-core'
import { StatusBadge } from '@spree/dashboard-ui'
import { BanknoteIcon } from '@spree/dashboard-ui/icons'
import type { Transfer } from '@spree/seller-sdk'
import { Link } from '@tanstack/react-router'
import i18n from 'i18next'
import { useStoreTimezone } from '../hooks/use-store-timezone'

/**
 * The sale behind an earning — what a seller checking a figure wants next.
 *
 * Its own component because a table definition is module-level and holds no
 * router context, while the link needs the seller whose panel this is. That
 * is what `useTenantId` answers, and a cell is rendered inside React like any
 * other component.
 */
function OrderCell({ transfer }: { transfer: Transfer }) {
  const sellerId = useTenantId()

  if (!transfer.order_id) return <>—</>

  return (
    <Link
      to="/$sellerId/orders/$orderId"
      params={{ sellerId, orderId: transfer.order_id }}
      className="no-underline"
    >
      {transfer.order_number ?? transfer.order_id}
    </Link>
  )
}

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
const KINDS = ['earning', 'refund_reversal'] as const

defineTable<Transfer>('seller-transfers', {
  title: i18n.t('earnings.transfers.title'),
  // Without this the toolbar sends `name_cont`, which the ledger does not
  // whitelist — Ransack drops an unknown condition, so the box would look
  // like it worked and return everything.
  searchParam: 'reference_cont',
  searchPlaceholder: i18n.t('earnings.search_placeholder'),
  defaultSort: { field: 'created_at', direction: 'desc' },
  emptyIcon: <BanknoteIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('earnings.transfers.empty'),
  columns: [
    {
      key: 'created_at',
      label: i18n.t('earnings.columns.date'),
      sortable: true,
      filterable: true,
      filterType: 'date',
      quickFilter: true,
      default: true,
      render: (transfer) => <LedgerDate iso={transfer.created_at} />,
    },
    {
      key: 'order_number',
      label: i18n.t('earnings.columns.order'),
      default: true,
      render: (transfer) => <OrderCell transfer={transfer} />,
    },
    {
      key: 'kind',
      label: i18n.t('earnings.columns.kind'),
      filterable: true,
      filterType: 'enum',
      filterOptions: KINDS.map((kind) => ({
        value: kind,
        label: i18n.t(`earnings.kinds.${kind}`),
      })),
      quickFilter: true,
      default: true,
      render: (transfer) =>
        i18n.t(`earnings.kinds.${transfer.kind}`, { defaultValue: transfer.kind }),
    },
    {
      key: 'status',
      label: i18n.t('earnings.columns.status'),
      sortable: true,
      filterable: true,
      filterType: 'enum',
      filterOptions: STATUSES.map((status) => ({
        value: status,
        label: i18n.t(`earnings.statuses.${status}`),
      })),
      quickFilter: true,
      default: true,
      render: (transfer) => (
        <StatusBadge
          status={transfer.status}
          label={i18n.t(`earnings.statuses.${transfer.status}`, { defaultValue: transfer.status })}
        />
      ),
    },
    {
      key: 'amount',
      label: i18n.t('earnings.columns.amount'),
      sortable: true,
      default: true,
      className: 'text-right tabular-nums',
      render: (transfer) => transfer.display_amount,
    },
  ],
})
