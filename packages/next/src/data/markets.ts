import type { Market, Country } from '@spree/sdk';
import { getClient } from '../config';
import { getLocaleOptions } from '../locale';
import type { SpreeNextOptions } from '../types';

/**
 * List all markets for the current store.
 * Each market contains currency, locales, tax_inclusive flag, and countries.
 */
export async function listMarkets(
  options?: SpreeNextOptions
): Promise<{ data: Market[] }> {
  const resolved = options ?? await getLocaleOptions();
  return getClient().markets.list(resolved);
}

/**
 * Get a market by prefixed ID.
 * @param id - Market prefixed ID (e.g., "mkt_k5nR8xLq")
 */
export async function getMarket(
  id: string,
  options?: SpreeNextOptions
): Promise<Market> {
  const resolved = options ?? await getLocaleOptions();
  return getClient().markets.get(id, resolved);
}

/**
 * Resolve which market applies for a given country.
 * @param country - ISO 3166-1 alpha-2 code (e.g., "DE", "US")
 */
export async function resolveMarket(
  country: string,
  options?: SpreeNextOptions
): Promise<Market> {
  const resolved = options ?? await getLocaleOptions();
  return getClient().markets.resolve(country, resolved);
}

/**
 * List countries belonging to a market.
 * @param marketId - Market prefixed ID
 */
export async function listMarketCountries(
  marketId: string,
  options?: SpreeNextOptions
): Promise<{ data: Country[] }> {
  const resolved = options ?? await getLocaleOptions();
  return getClient().markets.countries.list(marketId, resolved);
}

/**
 * Get a country by ISO code within a market.
 * @param marketId - Market prefixed ID
 * @param iso - Country ISO code (e.g., "DE")
 */
export async function getMarketCountry(
  marketId: string,
  iso: string,
  params?: { expand?: string[] },
  options?: SpreeNextOptions
): Promise<Country> {
  const resolved = options ?? await getLocaleOptions();
  return getClient().markets.countries.get(marketId, iso, params, resolved);
}
