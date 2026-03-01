import type { StoreCurrency } from '@spree/sdk';
import { getClient } from '../config';
import { getLocaleOptions } from '../locale';
import type { SpreeNextOptions } from '../types';

/**
 * List currencies supported by the store (derived from markets).
 * Locale/country are auto-read from cookies when not provided.
 */
export async function listCurrencies(
  options?: SpreeNextOptions
): Promise<{ data: StoreCurrency[] }> {
  const resolved = options ?? await getLocaleOptions();
  return getClient().store.currencies.list(resolved);
}
