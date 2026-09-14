import type { StoreCredit } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { Badge, RelativeTime, ResourceNameCell } from '@spree/dashboard-ui'
import { BanknoteIcon } from '@spree/dashboard-ui/icons'
import i18n from 'i18next'
import { adminUserAutocompleteProps } from '../hooks/use-admin-users'
import { customerAutocompleteProps } from '../hooks/use-customers'
import { erasedFieldValue } from '../lib/erased-customer'
import { translatedLabel } from '../lib/translated-label'

/**
 * Why the credit exists, read off the polymorphic originator. A credit an
 * admin issued by hand has none, which is itself the answer.
 */
export function originLabel(originatorType: string | null | undefined): string {
  if (!originatorType) return i18n.t('admin.store_credits.origins.manual')

  return translatedLabel('admin.store_credits.origins', originatorType)
}

const ORIGIN_OPTIONS = [
  { value: 'true', label: i18n.t('admin.store_credits.origins.gift_card') },
  { value: 'false', label: i18n.t('admin.store_credits.filters.not_from_gift_card') },
]

defineTable<StoreCredit>('store-credits', {
  docsPath: 'loyalty/store-credits',
  description: i18n.t('admin.table_descriptions.store_credits'),
  title: i18n.t('admin.nav.store_credits'),
  searchParam: 'memo_cont',
  searchPlaceholder: i18n.t('admin.store_credits.table.search_placeholder'),
  defaultSort: { field: 'created_at', direction: 'desc' },
  emptyIcon: <BanknoteIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.store_credits.table.empty'),
  columns: [
    {
      key: 'customer',
      label: i18n.t('admin.store_credits.columns.customer'),
      ransackAttribute: 'customer_id',
      filterable: true,
      filterType: 'resource',
      filterResource: customerAutocompleteProps('store-credit-customer-filter'),
      expand: 'customer',
      default: true,
      render: (credit) => (
        <ResourceNameCell
          id={credit.id}
          dataAttr="data-store-credit-id"
          name={
            credit.customer
              ? erasedFieldValue(credit.customer.email, credit.customer.anonymized)
              : i18n.t('admin.store_credits.no_customer')
          }
          secondary={credit.memo ?? undefined}
        />
      ),
    },
    {
      key: 'display_amount',
      label: i18n.t('admin.fields.store_credit.amount.label'),
      default: true,
      className: 'text-right tabular-nums whitespace-nowrap font-medium',
      render: (credit) => credit.display_amount,
    },
    {
      key: 'display_amount_used',
      label: i18n.t('admin.store_credits.columns.used'),
      default: true,
      className: 'text-right tabular-nums whitespace-nowrap',
      render: (credit) => credit.display_amount_used,
    },
    {
      key: 'display_amount_remaining',
      label: i18n.t('admin.store_credits.columns.remaining'),
      default: true,
      className: 'text-right tabular-nums whitespace-nowrap',
      render: (credit) => credit.display_amount_remaining,
    },
    {
      // Money still owed versus money already spent. The two states are
      // mutually exclusive and each is one argument to the `outstanding`
      // scope, so this is an enum of scope values rather than a `boolean`
      // column: a boolean renders a two-item multi-select, and a scope takes
      // a single argument, so a multi-value selection has no call that
      // expresses it.
      key: 'outstanding',
      label: i18n.t('admin.store_credits.columns.standing'),
      ransackAttribute: 'outstanding',
      ransackScope: true,
      sortable: false,
      filterable: true,
      filterType: 'enum',
      filterOptions: [
        { value: 'true', label: i18n.t('admin.store_credits.filters.outstanding') },
        { value: 'false', label: i18n.t('admin.store_credits.filters.spent') },
      ],
      quickFilter: true,
      default: false,
      // Server-computed, so the badge and the filter behind it answer the
      // same question — deriving it here from the money columns would drift
      // the moment "spendable" changes meaning.
      render: (credit) =>
        credit.outstanding ? (
          <Badge variant="secondary">{i18n.t('admin.store_credits.filters.outstanding')}</Badge>
        ) : (
          <Badge variant="outline">{i18n.t('admin.store_credits.filters.spent')}</Badge>
        ),
    },
    {
      key: 'currency',
      label: i18n.t('admin.fields.store_credit.currency.label'),
      sortable: true,
      filterable: true,
      filterType: 'currency',
      default: true,
      render: (credit) => credit.currency,
    },
    {
      key: 'originator_type',
      label: i18n.t('admin.store_credits.columns.origin'),
      // The filter asks "did a gift card issue this", which is the question a
      // merchant reconciling balances has; `originator_type` itself carries
      // Ruby class names the client should never send.
      ransackAttribute: 'from_gift_card',
      ransackScope: true,
      sortable: false,
      filterable: true,
      filterType: 'enum',
      filterOptions: ORIGIN_OPTIONS,
      default: true,
      render: (credit) => <Badge variant="outline">{originLabel(credit.originator_type)}</Badge>,
    },
    {
      key: 'created_by',
      label: i18n.t('admin.store_credits.columns.issued_by'),
      ransackAttribute: 'created_by_id',
      filterable: true,
      filterType: 'resource',
      filterResource: adminUserAutocompleteProps('store-credit-created-by-filter'),
      expand: 'created_by',
      sortable: false,
      default: false,
      render: (credit) => credit.created_by?.email ?? '—',
    },
    {
      key: 'created_at',
      label: i18n.t('admin.fields.created_at.label'),
      sortable: true,
      filterable: true,
      filterType: 'date',
      default: true,
      className: 'text-sm text-muted-foreground whitespace-nowrap',
      render: (credit) => <RelativeTime iso={credit.created_at} />,
    },
  ],
})
