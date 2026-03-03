import type { StoreCountry } from '@spree/sdk';
import { getClient } from '../config';
import { getLocaleOptions } from '../locale';
import type { SpreeNextOptions } from '../types';

/**
 * List countries available in the store.
 * Use ?include=market to include market details (currency, locale, tax_inclusive).
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
 * @param params - Optional params (e.g., { include: 'states' } or { include: 'market' })
 */
export async function getCountry(
  iso: string,
  params?: { include?: string },
  options?: SpreeNextOptions
): Promise<StoreCountry> {
  const resolved = options ?? await getLocaleOptions();
  return getClient().store.countries.get(iso, params, resolved);
}
