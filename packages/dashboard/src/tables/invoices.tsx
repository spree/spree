import type { Invoice } from '@spree/admin-sdk'
import { INVOICE_KINDS } from '@spree/core'
import { defineTable, Money } from '@spree/dashboard-core'
import { RelativeTime, StatusBadge } from '@spree/dashboard-ui'
import { ReceiptTextIcon } from '@spree/dashboard-ui/icons'
import { Link } from '@tanstack/react-router'
import i18n from 'i18next'

function kindLabel(kind: string): string {
  return i18n.t(`admin.order_documents.kinds.${kind}`, { defaultValue: kind })
}

/**
 * Every invoice, receipt and credit note in the store, whichever order or
 * seller payout it belongs to. Uploaded and acted on from that order or payout.
 */
defineTable<Invoice>('invoices', {
  title: i18n.t('admin.nav.invoices'),
  description: i18n.t('admin.table_descriptions.invoices'),
  docsPath: 'orders/invoices',
  searchParam: 'number_cont',
  searchPlaceholder: i18n.t('admin.invoices.search_placeholder'),
  defaultSort: { field: 'issued_on', direction: 'desc' },
  emptyIcon: <ReceiptTextIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.invoices.empty'),
  columns: [
    {
      key: 'number',
      label: i18n.t('admin.invoices.number'),
      sortable: true,
      default: true,
      render: (invoice) =>
        invoice.order_id ? (
          <Link
            to={'/$storeId/orders/$orderId' as string}
            params={{ orderId: invoice.order_id }}
            className="font-medium text-foreground no-underline"
          >
            {invoice.number}
          </Link>
        ) : invoice.seller_payout_id ? (
          <Link
            to={'/$storeId/sellers/payouts/$payoutId' as string}
            params={{ payoutId: invoice.seller_payout_id }}
            className="font-medium text-foreground no-underline"
          >
            {invoice.number}
          </Link>
        ) : (
          invoice.number
        ),
    },
    {
      key: 'kind',
      label: i18n.t('admin.invoices.kind'),
      sortable: true,
      filterable: true,
      filterType: 'enum',
      filterOptions: INVOICE_KINDS.map((value) => ({ value, label: kindLabel(value) })),
      quickFilter: true,
      default: true,
      render: (invoice) => (
        <StatusBadge
          status={invoice.kind}
          tone={invoice.kind === 'credit_note' ? 'warning' : 'neutral'}
          label={kindLabel(invoice.kind)}
        />
      ),
    },
    {
      key: 'order',
      label: i18n.t('admin.nav.orders'),
      default: true,
      render: (invoice) => invoice.order?.number ?? '—',
    },
    {
      key: 'issuer_name',
      label: i18n.t('admin.invoices.issuer'),
      default: true,
      render: (invoice) => invoice.issuer_name ?? '—',
    },
    {
      key: 'total',
      label: i18n.t('admin.invoices.total'),
      sortable: true,
      default: true,
      render: (invoice) => <Money amount={invoice.total} currency={invoice.currency} />,
    },
    {
      key: 'issued_on',
      label: i18n.t('admin.invoices.issued_on'),
      sortable: true,
      filterable: true,
      filterType: 'date',
      default: true,
      render: (invoice) => invoice.issued_on,
    },
    {
      key: 'sent_at',
      label: i18n.t('admin.invoices.sent_at'),
      sortable: true,
      default: true,
      render: (invoice) =>
        invoice.sent_at ? (
          <RelativeTime iso={invoice.sent_at} />
        ) : (
          i18n.t('admin.order_documents.not_sent')
        ),
    },
  ],
})
