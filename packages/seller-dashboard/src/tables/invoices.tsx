import { INVOICE_KINDS } from '@spree/core'
import {
  defineTable,
  downloadFromApi,
  formatMoney,
  getApiClient,
  useAuth,
} from '@spree/dashboard-core'
import { Button, StatusBadge } from '@spree/dashboard-ui'
import { ReceiptTextIcon } from '@spree/dashboard-ui/icons'
import type { Invoice } from '@spree/seller-sdk'
import i18n from 'i18next'

function kindLabel(kind: string): string {
  return i18n.t(`admin.order_documents.kinds.${kind}`, { defaultValue: kind })
}

/** The invoice number, downloading the PDF through the Seller API. */
function InvoiceNumber({ invoice }: { invoice: Invoice }) {
  const { token } = useAuth()

  return (
    <Button
      type="button"
      variant="link"
      className="h-auto p-0 font-medium"
      onClick={() =>
        invoice.download_url &&
        downloadFromApi(
          token,
          invoice.download_url,
          invoice.file_filename ?? invoice.number,
          getApiClient().downloadHeaders?.() ?? {},
        )
      }
    >
      {invoice.number}
    </Button>
  )
}

defineTable<Invoice>('seller-invoices', {
  title: i18n.t('invoices.title'),
  searchParam: 'number_cont',
  searchPlaceholder: i18n.t('invoices.search_placeholder'),
  defaultSort: { field: 'issued_on', direction: 'desc' },
  emptyIcon: <ReceiptTextIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('invoices.empty'),
  columns: [
    {
      key: 'number',
      label: i18n.t('invoices.columns.number'),
      sortable: true,
      default: true,
      render: (invoice) => <InvoiceNumber invoice={invoice} />,
    },
    {
      key: 'kind',
      label: i18n.t('invoices.columns.kind'),
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
      key: 'issuer_name',
      label: i18n.t('invoices.columns.issuer'),
      default: true,
      render: (invoice) =>
        invoice.seller_payout_id ? i18n.t('invoices.commission') : (invoice.issuer_name ?? '—'),
    },
    {
      key: 'total',
      label: i18n.t('invoices.columns.total'),
      sortable: true,
      default: true,
      render: (invoice) => formatMoney(invoice.total, invoice.currency, i18n.language),
    },
    {
      key: 'issued_on',
      label: i18n.t('invoices.columns.issued_on'),
      sortable: true,
      filterable: true,
      filterType: 'date',
      default: true,
      render: (invoice) => invoice.issued_on,
    },
  ],
})
