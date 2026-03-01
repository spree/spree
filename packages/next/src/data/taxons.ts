import type { StoreTaxon, StoreProduct, PaginatedResponse, TaxonListParams, ProductListParams } from '@spree/sdk';
import { getClient } from '../config';
import type { SpreeNextOptions } from '../types';

/**
 * List taxons (categories) with optional filtering and pagination.
 */
export async function listTaxons(
  params?: TaxonListParams,
  options?: SpreeNextOptions
): Promise<PaginatedResponse<StoreTaxon>> {
  return getClient().store.taxons.list(params, {
    locale: options?.locale,
    currency: options?.currency,
  });
}

/**
 * Get a single taxon by ID or permalink.
 */
export async function getTaxon(
  idOrPermalink: string,
  params?: Record<string, unknown>,
  options?: SpreeNextOptions
): Promise<StoreTaxon> {
  return getClient().store.taxons.get(idOrPermalink, params, {
    locale: options?.locale,
    currency: options?.currency,
  });
}

/**
 * List products within a taxon.
 */
export async function listTaxonProducts(
  taxonId: string,
  params?: ProductListParams,
  options?: SpreeNextOptions
): Promise<PaginatedResponse<StoreProduct>> {
  return getClient().store.taxons.products.list(taxonId, params, {
    locale: options?.locale,
    currency: options?.currency,
  });
}
