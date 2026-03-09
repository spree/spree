import type { Taxon, Product, PaginatedResponse, TaxonListParams, ProductListParams } from '@spree/sdk';
import { getClient } from '../config';
import { getLocaleOptions } from '../locale';
import type { SpreeNextOptions } from '../types';

/**
 * List taxons (categories) with optional filtering and pagination.
 * Locale/country are auto-read from cookies when not provided.
 */
export async function listTaxons(
  params?: TaxonListParams,
  options?: SpreeNextOptions
): Promise<PaginatedResponse<Taxon>> {
  const resolved = options ?? await getLocaleOptions();
  return getClient().taxons.list(params, resolved);
}

/**
 * Get a single taxon by ID or permalink.
 * Locale/country are auto-read from cookies when not provided.
 */
export async function getTaxon(
  idOrPermalink: string,
  params?: Record<string, unknown>,
  options?: SpreeNextOptions
): Promise<Taxon> {
  const resolved = options ?? await getLocaleOptions();
  return getClient().taxons.get(idOrPermalink, params, resolved);
}

/**
 * List products within a taxon.
 * Locale/country are auto-read from cookies when not provided.
 */
export async function listTaxonProducts(
  taxonId: string,
  params?: ProductListParams,
  options?: SpreeNextOptions
): Promise<PaginatedResponse<Product>> {
  const resolved = options ?? await getLocaleOptions();
  return getClient().taxons.products.list(taxonId, params, resolved);
}
