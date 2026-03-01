import type { StoreStore } from '@spree/sdk';
import { getClient } from '../config';
import { getLocaleOptions } from '../locale';
import type { SpreeNextOptions } from '../types';

/**
 * Get the current store configuration.
 * Locale/country are auto-read from cookies when not provided.
 */
export async function getStore(options?: SpreeNextOptions): Promise<StoreStore> {
  const resolved = options ?? await getLocaleOptions();
  return getClient().store.store.get(resolved);
}
