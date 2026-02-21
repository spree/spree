import type { StoreCountry } from '@spree/sdk';
import { getClient } from '../config';
import type { SpreeNextOptions } from '../types';

/**
 * List countries available in the store.
 * Each country includes currency and default_locale derived from its market.
 */
export async function listCountries(
  options?: SpreeNextOptions
): Promise<{ data: StoreCountry[] }> {
  return getClient().store.countries.list({
    locale: options?.locale,
    currency: options?.currency,
  });
}

/**
 * Get a country by ISO code.
 * @param iso - ISO 3166-1 alpha-2 code (e.g., "US", "DE")
 * @param params - Optional params (e.g., { include: 'states' } for address forms)
 */
export async function getCountry(
  iso: string,
  params?: { include?: string },
  options?: SpreeNextOptions
): Promise<StoreCountry> {
  return getClient().store.countries.get(iso, params, {
    locale: options?.locale,
    currency: options?.currency,
  });
}
