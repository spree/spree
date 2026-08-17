import type { CommissionRate } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { ActiveBadge, ResourceNameCell } from '@spree/dashboard-ui'
import i18n from 'i18next'
import { HandCoinsIcon } from 'lucide-react'

defineTable<CommissionRate>('commission-rates', {
  title: i18n.t('admin.settings_nav.items.commission_rates'),
  searchParam: 'name_cont',
  searchPlaceholder: i18n.t('admin.commission_rates.search_placeholder'),
  // The list IS the resolution order, walked top-down, so the table has to
  // show it in that order and nothing else. Sorting by another column would
  // show a sequence the engine does not follow.
  defaultSort: { field: 'position', direction: 'asc' },
  emptyIcon: <HandCoinsIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.commission_rates.empty'),
  columns: [
    {
      key: 'name',
      label: i18n.t('admin.fields.name.label'),
      sortable: true,
      filterable: true,
      default: true,
      render: (rate) => (
        <ResourceNameCell
          id={rate.id}
          dataAttr="data-commission-rate-id"
          name={rate.name}
          secondary={rate.code}
        />
      ),
    },
    {
      key: 'value',
      label: i18n.t('admin.fields.commission_rate.value.label'),
      sortable: true,
      default: true,
      // A flat fee states an amount per currency, so the cell lists them —
      // "5.00 USD, 4.00 GBP" — rather than showing one and implying the rest.
      render: (rate) =>
        rate.kind === 'percentage'
          ? `${rate.value}%`
          : Object.entries(rate.amounts ?? {})
              .map(([currency, amount]) => `${amount} ${currency}`)
              .join(', '),
    },
    {
      key: 'rules',
      label: i18n.t('admin.fields.commission_rate.rules.label'),
      default: true,
      // The conditions by name — "Seller, Sale value" — rather than the records
      // inside them, which would run to a paragraph on a rate naming fifty
      // products. The editor shows what each one holds.
      render: (rate) =>
        rate.rules?.length ? (
          rate.rules
            .map((rule) => rule.label)
            .filter(Boolean)
            .join(', ')
        ) : (
          // A rate naming nothing matches every sale, so everything below it
          // never resolves. Worth saying plainly in the row.
          <span className="text-muted-foreground">
            {i18n.t('admin.commission_rates.applies_to_everything')}
          </span>
        ),
    },
    {
      key: 'enabled',
      label: i18n.t('admin.fields.enabled.label'),
      default: true,
      render: (rate) => (
        <ActiveBadge
          active={rate.enabled}
          activeLabel={i18n.t('admin.fields.enabled.label')}
          dashWhenInactive
        />
      ),
    },
  ],
})
