import type { StoreCurrency } from '@spree/sdk';
import { getClient } from '../config';
import type { SpreeNextOptions } from '../types';

/**
 * List currencies supported by the store (derived from markets).
 */
export async function listCurrencies(
  options?: SpreeNextOptions
): Promise<{ data: StoreCurrency[] }> {
  return getClient().store.currencies.list({
    locale: options?.locale,
    currency: options?.currency,
  });
}
