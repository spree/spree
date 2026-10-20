import type { CurrencyCode, LocaleCode, Market, PaginatedResponse } from '@spree/admin-sdk'
import { adminClient } from '../client'

/**
 * Markets and channels are store configuration that rarely changes, so the
 * dashboard fetches each list once and keeps it for an hour. Their create,
 * update and delete mutations invalidate `[resource, storeId]`, which refreshes
 * the cached list immediately.
 */
export const STORE_CONFIG_STALE_TIME = 60 * 60_000

const PAGE_SIZE = 100

/**
 * Fetches every page of a list and joins them, so a store with more records
 * than one page holds still gets all of them.
 */
async function listEveryPage<T>(
  fetchPage: (page: number) => Promise<PaginatedResponse<T>>,
): Promise<PaginatedResponse<T>> {
  const first = await fetchPage(1)
  if (first.meta.pages <= 1) return first

  const rest = await Promise.all(
    Array.from({ length: first.meta.pages - 1 }, (_, index) => fetchPage(index + 2)),
  )
  return { ...first, data: [first, ...rest].flatMap((response) => response.data) }
}

/** Every market of the current store, under `['markets', storeId, 'all']`. */
export function listAllMarkets() {
  return listEveryPage((page) =>
    adminClient.markets.list({ page, limit: PAGE_SIZE, sort: 'position' }),
  )
}

/** Every channel of the current store, under `['channels', storeId, 'all']`. */
export function listAllChannels() {
  return listEveryPage((page) => adminClient.channels.list({ page, limit: PAGE_SIZE }))
}

export interface MarketLocalization {
  /** The default market's currency first, then every other market's. */
  currencies: CurrencyCode[]
  /** Every language any market offers, sorted. */
  locales: LocaleCode[]
  defaultCurrency: CurrencyCode | undefined
  defaultLocale: LocaleCode | undefined
}

/**
 * The currencies and languages a store sells in, read from its markets. The
 * default market's currency and language are the store's defaults.
 */
export function marketLocalization(markets: readonly Market[]): MarketLocalization {
  const defaultMarket = markets.find((market) => market.default) ?? markets[0]
  const currencies = [
    ...new Set([
      ...(defaultMarket ? [defaultMarket.currency] : []),
      ...markets.map((market) => market.currency),
    ]),
  ]
  const locales = [
    ...new Set(
      markets.flatMap((market) => [market.default_locale, ...(market.supported_locales ?? [])]),
    ),
  ].sort()

  return {
    currencies,
    locales,
    defaultCurrency: defaultMarket?.currency,
    defaultLocale: defaultMarket?.default_locale,
  }
}
