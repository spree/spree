import type { StoreStore } from '@spree/sdk';
import { getClient } from '../config';
import type { SpreeNextOptions } from '../types';

/**
 * Get the current store configuration.
 */
export async function getStore(options?: SpreeNextOptions): Promise<StoreStore> {
  return getClient().store.store.get({
    locale: options?.locale,
    currency: options?.currency,
  });
}
