import type { StoreTaxonomy, PaginatedResponse } from '@spree/sdk';
import { getClient } from '../config';
import { getLocaleOptions } from '../locale';
import type { SpreeNextOptions } from '../types';

/**
 * List taxonomies with optional filtering and pagination.
 * Locale/country are auto-read from cookies when not provided.
 */
export async function listTaxonomies(
  params?: Record<string, unknown>,
  options?: SpreeNextOptions
): Promise<PaginatedResponse<StoreTaxonomy>> {
  const resolved = options ?? await getLocaleOptions();
  return getClient().store.taxonomies.list(params, resolved);
}

/**
 * Get a single taxonomy by ID.
 * Locale/country are auto-read from cookies when not provided.
 */
export async function getTaxonomy(
  id: string,
  params?: Record<string, unknown>,
  options?: SpreeNextOptions
): Promise<StoreTaxonomy> {
  const resolved = options ?? await getLocaleOptions();
  return getClient().store.taxonomies.get(id, params, resolved);
}
