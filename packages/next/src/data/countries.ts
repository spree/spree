import type { Country } from '@spree/sdk';
import { getClient } from '../config';
import { getLocaleOptions } from '../locale';
import type { SpreeNextOptions } from '../types';

/**
 * List countries available in the store.
 * Use ?expand=market to expand market details (currency, locale, tax_inclusive).
 */
export async function listCountries(
  options?: SpreeNextOptions
): Promise<{ data: Country[] }> {
  const resolved = options ?? await getLocaleOptions();
  return getClient().countries.list(resolved);
}

/**
 * Get a country by ISO code.
 * @param iso - ISO 3166-1 alpha-2 code (e.g., "US", "DE")
 * @param params - Optional params (e.g., { expand: ['states'] } or { expand: ['market'] })
 */
export async function getCountry(
  iso: string,
  params?: { expand?: string[] },
  options?: SpreeNextOptions
): Promise<Country> {
  const resolved = options ?? await getLocaleOptions();
  return getClient().countries.get(iso, params, resolved);
}
