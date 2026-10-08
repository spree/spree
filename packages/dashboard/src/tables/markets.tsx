import type { Market } from '@spree/admin-sdk'
import { defineTable, LocaleLabel } from '@spree/dashboard-core'
import { ActiveBadge, Badge, ResourceNameCell } from '@spree/dashboard-ui'
import { GlobeIcon } from '@spree/dashboard-ui/icons'
import i18n from 'i18next'
import { useTranslation } from 'react-i18next'
import { effectiveTaxProvider, useTaxProviders } from '../hooks/use-tax-rates'

/** A dash where the market's tax provider decides inclusiveness without the market's flag. */
function MarketTaxInclusiveCell({ market }: { market: Market }) {
  const { t } = useTranslation()
  const { providers } = useTaxProviders()

  if (!effectiveTaxProvider(providers, market.tax_provider)?.uses_market_tax_inclusive) {
    return <span className="text-muted-foreground">—</span>
  }

  return (
    <ActiveBadge
      active={market.tax_inclusive}
      activeLabel={t('admin.markets.tax_inclusive')}
      inactiveLabel={t('admin.markets.tax_exclusive')}
    />
  )
}

defineTable<Market>('markets', {
  title: i18n.t('admin.settings_nav.items.markets'),
  docsPath: 'settings/markets',
  description: i18n.t('admin.table_descriptions.markets'),
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
      default: true,
      render: (market) => (
        <ResourceNameCell
          id={market.id}
          dataAttr="data-market-id"
          name={market.name}
          secondary={market.country_codes.length > 0 ? market.country_codes.join(', ') : undefined}
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
      render: (market) => <MarketTaxInclusiveCell market={market} />,
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
