import type { StoreLocale } from '@spree/sdk';
import { getClient } from '../config';
import { getLocaleOptions } from '../locale';
import type { SpreeNextOptions } from '../types';

/**
 * List locales supported by the store (derived from markets).
 * Locale/country are auto-read from cookies when not provided.
 */
export async function listLocales(
  options?: SpreeNextOptions
): Promise<{ data: StoreLocale[] }> {
  const resolved = options ?? await getLocaleOptions();
  return getClient().store.locales.list(resolved);
}
