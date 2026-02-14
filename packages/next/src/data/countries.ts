import type { StoreCountry } from '@spree/sdk';
import { getClient } from '../config';
import type { SpreeNextOptions } from '../types';

/**
 * List all available countries.
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
 * Get a single country by ISO code.
 */
export async function getCountry(
  iso: string,
  options?: SpreeNextOptions
): Promise<StoreCountry> {
  return getClient().store.countries.get(iso, {
    locale: options?.locale,
    currency: options?.currency,
  });
}
