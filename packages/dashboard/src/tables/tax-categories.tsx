import type { TaxCategory } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { ActiveBadge, ResourceNameCell } from '@spree/dashboard-ui'
import i18n from 'i18next'
import { PercentIcon } from 'lucide-react'

defineTable<TaxCategory>('tax-categories', {
  title: i18n.t('admin.settings_nav.items.tax_categories'),
  searchParam: 'name_cont',
  searchPlaceholder: i18n.t('admin.tax_categories.search_placeholder'),
  defaultSort: { field: 'name', direction: 'asc' },
  emptyIcon: <PercentIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.tax_categories.empty'),
  columns: [
    {
      key: 'name',
      label: i18n.t('admin.fields.name.label'),
      sortable: true,
      filterable: true,
      default: true,
      render: (tc) => (
        <ResourceNameCell
          id={tc.id}
          dataAttr="data-tax-category-id"
          name={tc.name}
          secondary={tc.description}
        />
      ),
    },
    {
      key: 'tax_code',
      label: i18n.t('admin.fields.tax_category.tax_code.label'),
      sortable: true,
      filterable: true,
      default: true,
      render: (tc) => tc.tax_code ?? '—',
    },
    {
      key: 'is_default',
      label: i18n.t('admin.fields.tax_category.is_default.label'),
      default: true,
      render: (tc) => (
        <ActiveBadge
          active={tc.is_default}
          activeLabel={i18n.t('admin.fields.tax_category.is_default.label')}
          dashWhenInactive
        />
      ),
    },
  ],
})
