'use server';

import type { StoreCredit, PaginatedResponse, ListParams } from '@spree/sdk';
import { withAuthRefresh } from '../auth-helpers';
import { getClient } from '../config';

/**
 * List store credits for the authenticated customer.
 * Filtered by current store and currency on the backend.
 */
export async function listStoreCredits(
  params?: ListParams
): Promise<PaginatedResponse<StoreCredit>> {
  return withAuthRefresh(async (options) => {
    return getClient().customer.storeCredits.list(params, options);
  });
}
