import type { Market } from '@spree/admin-sdk'
import { Subject, usePermissions } from '@spree/dashboard-core'
import {
  Alert,
  AlertDescription,
  Button,
  Item,
  ItemActions,
  ItemContent,
  ItemDescription,
  ItemMedia,
  ItemTitle,
} from '@spree/dashboard-ui'
import { CalculatorIcon, InfoIcon } from '@spree/dashboard-ui/icons'
import { Link, useParams } from '@tanstack/react-router'
import { useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import { useAllMarkets } from '../../../hooks/use-markets'
import { useTaxProviders } from '../../../hooks/use-tax-rates'

/** Spree's own engine, the only one that reads the store's tax rates. */
const INTERNAL_PROVIDER = 'internal'

interface ProviderMarkets {
  providerId: string
  providerName: string
  markets: Market[]
}

/**
 * The store's markets grouped by the tax engine each one uses. A market that
 * names no engine runs on the installation default. Empty for staff who
 * cannot read markets. `isLoading` tells a store still loading apart from one
 * whose markets settled on no engine.
 */
export function useMarketTaxProviders(): { groups: ProviderMarkets[]; isLoading: boolean } {
  const { permissions } = usePermissions()
  const canReadMarkets = permissions.can('read', Subject.Market)
  const { markets, isLoading: marketsLoading } = useAllMarkets({ enabled: canReadMarkets })
  const { data, isLoading: providersLoading } = useTaxProviders()

  const groups = useMemo(() => {
    if (!canReadMarkets) return []

    const providers = data?.data ?? []
    const defaultId = providers.find((provider) => provider.default)?.id ?? INTERNAL_PROVIDER
    const groups = new Map<string, ProviderMarkets>()

    for (const market of markets) {
      const providerId = market.tax_provider || defaultId
      const group = groups.get(providerId) ?? {
        providerId,
        providerName: providers.find((provider) => provider.id === providerId)?.name ?? providerId,
        markets: [],
      }
      group.markets.push(market)
      groups.set(providerId, group)
    }

    return [...groups.values()]
  }, [canReadMarkets, markets, data])

  return { groups, isLoading: providersLoading || (canReadMarkets && marketsLoading) }
}

/** Which tax engine each market uses, with a link to change it. */
export function TaxProviderSummary() {
  const { t } = useTranslation()
  const { storeId } = useParams({ strict: false }) as { storeId: string }
  const { groups } = useMarketTaxProviders()

  if (groups.length === 0) return null

  return (
    <Item variant="outline">
      <ItemMedia variant="icon">
        <CalculatorIcon />
      </ItemMedia>
      <ItemContent>
        <ItemTitle>{t('admin.taxes.providers_title')}</ItemTitle>
        {groups.map((group) => (
          <ItemDescription key={group.providerId}>
            {t('admin.taxes.provider_markets', {
              provider: group.providerName,
              markets: group.markets.map((market) => market.name).join(', '),
            })}
          </ItemDescription>
        ))}
      </ItemContent>
      <ItemActions>
        <Button variant="outline" size="sm" asChild>
          <Link to="/$storeId/settings/markets" params={{ storeId }}>
            {t('admin.taxes.manage_markets')}
          </Link>
        </Button>
      </ItemActions>
    </Item>
  )
}

/**
 * Says which markets ignore the tax rates, because their engine works tax out
 * itself. Shown rather than hiding the rates, since a store can mix markets on
 * Spree's rates with markets on an external service.
 */
export function TaxRatesUsageNote() {
  const { t } = useTranslation()
  const { groups } = useMarketTaxProviders()

  const external = groups.filter((group) => group.providerId !== INTERNAL_PROVIDER)
  if (external.length === 0) return null

  const markets = external
    .flatMap((group) => group.markets.map((market) => `${market.name} (${group.providerName})`))
    .join(', ')
  const noneUseRates = external.length === groups.length

  return (
    <Alert>
      <InfoIcon />
      <AlertDescription>
        {noneUseRates
          ? t('admin.taxes.rates_unused_everywhere', { markets })
          : t('admin.taxes.rates_unused_in', { markets })}
      </AlertDescription>
    </Alert>
  )
}
