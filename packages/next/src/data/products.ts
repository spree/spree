import type { StoreProduct, PaginatedResponse, ProductFiltersResponse } from '@spree/sdk';
import { getClient } from '../config';
import type { SpreeNextOptions } from '../types';

/**
 * List products with optional filtering, sorting, and pagination.
 */
export async function listProducts(
  params?: Record<string, unknown>,
  options?: SpreeNextOptions
): Promise<PaginatedResponse<StoreProduct>> {
  return getClient().products.list(params, {
    locale: options?.locale,
    currency: options?.currency,
  });
}

/**
 * Get a single product by slug or ID.
 */
export async function getProduct(
  slugOrId: string,
  params?: { includes?: string },
  options?: SpreeNextOptions
): Promise<StoreProduct> {
  return getClient().products.get(slugOrId, params, {
    locale: options?.locale,
    currency: options?.currency,
  });
}

/**
 * Get available product filters (price ranges, option values, etc.).
 */
export async function getProductFilters(
  params?: Record<string, unknown>,
  options?: SpreeNextOptions
): Promise<ProductFiltersResponse> {
  return getClient().products.filters(params, {
    locale: options?.locale,
    currency: options?.currency,
  });
}
