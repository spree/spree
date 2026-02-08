import { StoreOrder, PaginatedResponse } from '@spree/sdk';

/**
 * List the authenticated customer's orders.
 */
declare function listOrders(params?: Record<string, unknown>): Promise<PaginatedResponse<StoreOrder>>;
/**
 * Get a single order by ID or number.
 */
declare function getOrder(idOrNumber: string, params?: Record<string, unknown>): Promise<StoreOrder>;

export { getOrder, listOrders };
