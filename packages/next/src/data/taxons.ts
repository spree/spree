import type { StoreTaxon, StoreProduct, PaginatedResponse, TaxonListParams, ProductListParams } from '@spree/sdk';
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
): Promise<PaginatedResponse<StoreTaxon>> {
  const resolved = options ?? await getLocaleOptions();
  return getClient().store.taxons.list(params, resolved);
}

/**
 * Get a single taxon by ID or permalink.
 * Locale/country are auto-read from cookies when not provided.
 */
export async function getTaxon(
  idOrPermalink: string,
  params?: Record<string, unknown>,
  options?: SpreeNextOptions
): Promise<StoreTaxon> {
  const resolved = options ?? await getLocaleOptions();
  return getClient().store.taxons.get(idOrPermalink, params, resolved);
}

/**
 * List products within a taxon.
 * Locale/country are auto-read from cookies when not provided.
 */
export async function listTaxonProducts(
  taxonId: string,
  params?: ProductListParams,
  options?: SpreeNextOptions
): Promise<PaginatedResponse<StoreProduct>> {
  const resolved = options ?? await getLocaleOptions();
  return getClient().store.taxons.products.list(taxonId, params, resolved);
}
