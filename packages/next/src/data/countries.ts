import type { StoreCountry } from '@spree/sdk';
import { getClient } from '../config';
import { getLocaleOptions } from '../locale';
import type { SpreeNextOptions } from '../types';

/**
 * List countries available in the store.
 * Each country includes currency and default_locale derived from its market.
 * Locale/country are auto-read from cookies when not provided.
 */
export async function listCountries(
  options?: SpreeNextOptions
): Promise<{ data: StoreCountry[] }> {
  const resolved = options ?? await getLocaleOptions();
  return getClient().store.countries.list(resolved);
}

/**
 * Get a country by ISO code.
 * @param iso - ISO 3166-1 alpha-2 code (e.g., "US", "DE")
 * @param params - Optional params (e.g., { include: 'states' } for address forms)
 * Locale/country are auto-read from cookies when not provided.
 */
export async function getCountry(
  iso: string,
  params?: { include?: string },
  options?: SpreeNextOptions
): Promise<StoreCountry> {
  const resolved = options ?? await getLocaleOptions();
  return getClient().store.countries.get(iso, params, resolved);
}
