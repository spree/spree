import type { Market } from '@spree/admin-sdk'
import { defineTable, LocaleLabel } from '@spree/dashboard-core'
import { ActiveBadge, Badge, ResourceNameCell } from '@spree/dashboard-ui'
import i18n from 'i18next'
import { GlobeIcon } from 'lucide-react'

defineTable<Market>('markets', {
  title: i18n.t('admin.settings_nav.items.markets'),
  searchParam: 'name_cont',
  searchPlaceholder: i18n.t('admin.markets.search_placeholder'),
  defaultSort: { field: 'position', direction: 'asc' },
  emptyIcon: <GlobeIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.markets.empty'),
  columns: [
    {
      key: 'name',
      label: i18n.t('admin.fields.name.label'),
      sortable: true,
      filterable: true,
      default: true,
      render: (market) => (
        <ResourceNameCell
          id={market.id}
          dataAttr="data-market-id"
          name={market.name}
          secondary={market.country_isos.length > 0 ? market.country_isos.join(', ') : undefined}
        />
      ),
    },
    {
      key: 'currency',
      label: i18n.t('admin.fields.currency.label'),
      sortable: true,
      default: true,
      render: (market) => <Badge variant="outline">{market.currency}</Badge>,
    },
    {
      key: 'default_locale',
      label: i18n.t('admin.fields.market.default_locale.label'),
      sortable: true,
      default: true,
      render: (market) => <LocaleLabel code={market.default_locale} />,
    },
    {
      key: 'tax_inclusive',
      label: i18n.t('admin.fields.tax.label'),
      default: true,
      render: (market) => (
        <ActiveBadge
          active={market.tax_inclusive}
          activeLabel={i18n.t('admin.markets.tax_inclusive')}
          inactiveLabel={i18n.t('admin.markets.tax_exclusive')}
        />
      ),
    },
    {
      key: 'default',
      label: i18n.t('admin.markets.columns.default'),
      default: true,
      render: (market) => (
        <ActiveBadge
          active={market.default}
          activeLabel={i18n.t('admin.markets.columns.default')}
          dashWhenInactive
        />
      ),
    },
  ],
})
