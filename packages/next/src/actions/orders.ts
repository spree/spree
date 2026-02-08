'use server';

import type { StoreOrder, PaginatedResponse } from '@spree/sdk';
import { withAuthRefresh } from '../auth-helpers';
import { getClient } from '../config';

/**
 * List the authenticated customer's orders.
 */
export async function listOrders(
  params?: Record<string, unknown>
): Promise<PaginatedResponse<StoreOrder>> {
  return withAuthRefresh(async (options) => {
    return getClient().orders.list(params, options);
  });
}

/**
 * Get a single order by ID or number.
 */
export async function getOrder(
  idOrNumber: string,
  params?: Record<string, unknown>
): Promise<StoreOrder> {
  return withAuthRefresh(async (options) => {
    return getClient().orders.get(idOrNumber, params, options);
  });
}
