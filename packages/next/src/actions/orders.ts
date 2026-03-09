'use server';

import type { Order, PaginatedResponse, OrderListParams } from '@spree/sdk';
import { withAuthRefresh } from '../auth-helpers';
import { getClient } from '../config';

/**
 * List the authenticated customer's orders.
 */
export async function listOrders(
  params?: OrderListParams
): Promise<PaginatedResponse<Order>> {
  return withAuthRefresh(async (options) => {
    return getClient().customer.orders.list(params, options);
  });
}

/**
 * Get a single order by ID or number.
 */
export async function getOrder(
  idOrNumber: string,
  params?: Record<string, unknown>
): Promise<Order> {
  return withAuthRefresh(async (options) => {
    return getClient().orders.get(idOrNumber, params, options);
  });
}
