import type { StoreMarket, StoreCountry } from '@spree/sdk';
import { getClient } from '../config';
import type { SpreeNextOptions } from '../types';

/**
 * List all markets with their countries.
 * Used to build a country/currency switcher.
 */
export async function listMarkets(
  options?: SpreeNextOptions
): Promise<{ data: StoreMarket[] }> {
  return getClient().store.markets.list({
    locale: options?.locale,
    currency: options?.currency,
  });
}

/**
 * Get a single market by prefixed ID.
 */
export async function getMarket(
  id: string,
  options?: SpreeNextOptions
): Promise<StoreMarket> {
  return getClient().store.markets.get(id, {
    locale: options?.locale,
    currency: options?.currency,
  });
}

/**
 * Resolve which market a country belongs to.
 * @param countryIso - ISO 3166-1 alpha-2 code (e.g., "US", "DE")
 */
export async function resolveMarket(
  countryIso: string,
  options?: SpreeNextOptions
): Promise<StoreMarket> {
  return getClient().store.markets.resolve(countryIso, {
    locale: options?.locale,
    currency: options?.currency,
  });
}

/**
 * List countries in a market's zone (for checkout address forms).
 */
export async function listMarketCountries(
  marketId: string,
  options?: SpreeNextOptions
): Promise<{ data: StoreCountry[] }> {
  return getClient().store.markets.countries.list(marketId, {
    locale: options?.locale,
    currency: options?.currency,
  });
}

/**
 * Get a country by ISO code with states (for address form validation).
 */
export async function getMarketCountry(
  marketId: string,
  iso: string,
  options?: SpreeNextOptions
): Promise<StoreCountry> {
  return getClient().store.markets.countries.get(marketId, iso, {
    locale: options?.locale,
    currency: options?.currency,
  });
}
