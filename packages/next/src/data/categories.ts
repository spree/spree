import type { Category, Product, PaginatedResponse, CategoryListParams, ProductListParams } from '@spree/sdk';
import { getClient } from '../config';
import { getLocaleOptions } from '../locale';
import type { SpreeNextOptions } from '../types';

/**
 * List categories with optional filtering and pagination.
 * Locale/country are auto-read from cookies when not provided.
 */
export async function listCategories(
  params?: CategoryListParams,
  options?: SpreeNextOptions
): Promise<PaginatedResponse<Category>> {
  const resolved = options ?? await getLocaleOptions();
  return getClient().categories.list(params, resolved);
}

/**
 * Get a single category by ID or permalink.
 * Locale/country are auto-read from cookies when not provided.
 */
export async function getCategory(
  idOrPermalink: string,
  params?: Record<string, unknown>,
  options?: SpreeNextOptions
): Promise<Category> {
  const resolved = options ?? await getLocaleOptions();
  return getClient().categories.get(idOrPermalink, params, resolved);
}

/**
 * List products within a category.
 * Locale/country are auto-read from cookies when not provided.
 */
export async function listCategoryProducts(
  categoryId: string,
  params?: ProductListParams,
  options?: SpreeNextOptions
): Promise<PaginatedResponse<Product>> {
  const resolved = options ?? await getLocaleOptions();
  return getClient().categories.products.list(categoryId, params, resolved);
}
