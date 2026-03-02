import type { StoreProduct, PaginatedResponse, ProductFiltersResponse, ProductListParams } from '@spree/sdk';
import { getClient } from '../config';
import { getLocaleOptions } from '../locale';
import type { SpreeNextOptions } from '../types';

/**
 * List products with optional filtering, sorting, and pagination.
 * Locale/country are auto-read from cookies when not provided.
 */
export async function listProducts(
  params?: ProductListParams,
  options?: SpreeNextOptions
): Promise<PaginatedResponse<StoreProduct>> {
  const resolved = options ?? await getLocaleOptions();
  return getClient().store.products.list(params, resolved);
}

/**
 * Get a single product by slug or ID.
 * Locale/country are auto-read from cookies when not provided.
 */
export async function getProduct(
  slugOrId: string,
  params?: { includes?: string },
  options?: SpreeNextOptions
): Promise<StoreProduct> {
  const resolved = options ?? await getLocaleOptions();
  return getClient().store.products.get(slugOrId, params, resolved);
}

/**
 * Get available product filters (price ranges, option values, etc.).
 * Locale/country are auto-read from cookies when not provided.
 */
export async function getProductFilters(
  params?: Record<string, unknown>,
  options?: SpreeNextOptions
): Promise<ProductFiltersResponse> {
  const resolved = options ?? await getLocaleOptions();
  return getClient().store.products.filters(params, resolved);
}
