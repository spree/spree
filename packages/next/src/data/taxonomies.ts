import type { StoreTaxonomy, PaginatedResponse } from '@spree/sdk';
import { getClient } from '../config';
import type { SpreeNextOptions } from '../types';

/**
 * List taxonomies with optional filtering and pagination.
 */
export async function listTaxonomies(
  params?: Record<string, unknown>,
  options?: SpreeNextOptions
): Promise<PaginatedResponse<StoreTaxonomy>> {
  return getClient().taxonomies.list(params, {
    locale: options?.locale,
    currency: options?.currency,
  });
}

/**
 * Get a single taxonomy by ID.
 */
export async function getTaxonomy(
  id: string,
  params?: Record<string, unknown>,
  options?: SpreeNextOptions
): Promise<StoreTaxonomy> {
  return getClient().taxonomies.get(id, params, {
    locale: options?.locale,
    currency: options?.currency,
  });
}
