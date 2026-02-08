import { StoreTaxon, PaginatedResponse, StoreProduct } from '@spree/sdk';
import { SpreeNextOptions } from '../types.js';

/**
 * List taxons (categories) with optional filtering and pagination.
 */
declare function listTaxons(params?: Record<string, unknown>, options?: SpreeNextOptions): Promise<PaginatedResponse<StoreTaxon>>;
/**
 * Get a single taxon by ID or permalink.
 */
declare function getTaxon(idOrPermalink: string, params?: Record<string, unknown>, options?: SpreeNextOptions): Promise<StoreTaxon>;
/**
 * List products within a taxon.
 */
declare function listTaxonProducts(taxonId: string, params?: Record<string, unknown>, options?: SpreeNextOptions): Promise<PaginatedResponse<StoreProduct>>;

export { getTaxon, listTaxonProducts, listTaxons };
