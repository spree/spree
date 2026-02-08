import { StoreTaxonomy, PaginatedResponse } from '@spree/sdk';
import { SpreeNextOptions } from '../types.js';

/**
 * List taxonomies with optional filtering and pagination.
 */
declare function listTaxonomies(params?: Record<string, unknown>, options?: SpreeNextOptions): Promise<PaginatedResponse<StoreTaxonomy>>;
/**
 * Get a single taxonomy by ID.
 */
declare function getTaxonomy(id: string, params?: Record<string, unknown>, options?: SpreeNextOptions): Promise<StoreTaxonomy>;

export { getTaxonomy, listTaxonomies };
