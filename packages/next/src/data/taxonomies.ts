import type { Taxonomy, PaginatedResponse } from '@spree/sdk';
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
): Promise<PaginatedResponse<Taxonomy>> {
  const resolved = options ?? await getLocaleOptions();
  return getClient().taxonomies.list(params, resolved);
}

/**
 * Get a single taxonomy by ID.
 * Locale/country are auto-read from cookies when not provided.
 */
export async function getTaxonomy(
  id: string,
  params?: Record<string, unknown>,
  options?: SpreeNextOptions
): Promise<Taxonomy> {
  const resolved = options ?? await getLocaleOptions();
  return getClient().taxonomies.get(id, params, resolved);
}
