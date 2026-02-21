import type { StoreLocale } from '@spree/sdk';
import { getClient } from '../config';
import type { SpreeNextOptions } from '../types';

/**
 * List locales supported by the store (derived from markets).
 */
export async function listLocales(
  options?: SpreeNextOptions
): Promise<{ data: StoreLocale[] }> {
  return getClient().store.locales.list({
    locale: options?.locale,
    currency: options?.currency,
  });
}
