import type { TaxRate } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { ActiveBadge, ResourceNameCell } from '@spree/dashboard-ui'
import i18n from 'i18next'
import { ReceiptTextIcon } from 'lucide-react'
import { JurisdictionLabel } from '../components/spree/jurisdiction-label'
import { TaxCategoryLabel } from '../components/spree/tax-category-label'

defineTable<TaxRate>('tax-rates', {
  title: i18n.t('admin.settings_nav.items.tax_rates'),
  searchParam: 'name_cont',
  searchPlaceholder: i18n.t('admin.tax_rates.search_placeholder'),
  defaultSort: { field: 'name', direction: 'asc' },
  emptyIcon: <ReceiptTextIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.tax_rates.empty'),
  columns: [
    {
      key: 'name',
      label: i18n.t('admin.fields.name.label'),
      sortable: true,
      default: true,
      render: (taxRate) => (
        <ResourceNameCell id={taxRate.id} dataAttr="data-tax-rate-id" name={taxRate.name} />
      ),
    },
    {
      key: 'amount',
      label: i18n.t('admin.fields.tax_rate.amount.label'),
      sortable: true,
      default: true,
      render: (taxRate) =>
        taxRate.amount_percentage === null ? '—' : `${taxRate.amount_percentage}%`,
    },
    {
      key: 'country_code',
      label: i18n.t('admin.fields.tax_rate.jurisdiction.label'),
      sortable: true,
      filterable: true,
      default: true,
      render: (taxRate) => (
        <JurisdictionLabel countryCode={taxRate.country_code} stateCode={taxRate.state_code} />
      ),
    },
    {
      key: 'included_in_price',
      label: i18n.t('admin.fields.tax_rate.included_in_price.label'),
      default: true,
      render: (taxRate) => (
        <ActiveBadge
          active={taxRate.included_in_price}
          activeLabel={i18n.t('admin.fields.tax_rate.included_in_price.short')}
          dashWhenInactive
        />
      ),
    },
    {
      key: 'show_rate_in_label',
      label: i18n.t('admin.fields.tax_rate.show_rate_in_label.label'),
      render: (taxRate) => (
        <ActiveBadge
          active={taxRate.show_rate_in_label}
          activeLabel={i18n.t('admin.common.yes')}
          dashWhenInactive
        />
      ),
    },
    {
      key: 'tax_category_id',
      label: i18n.t('admin.settings_nav.items.tax_categories'),
      render: (taxRate) => <TaxCategoryLabel id={taxRate.tax_category_id} />,
    },
  ],
})
