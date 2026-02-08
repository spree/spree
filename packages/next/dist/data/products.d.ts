import { StoreProduct, ProductFiltersResponse, PaginatedResponse } from '@spree/sdk';
import { SpreeNextOptions } from '../types.js';

/**
 * List products with optional filtering, sorting, and pagination.
 */
declare function listProducts(params?: Record<string, unknown>, options?: SpreeNextOptions): Promise<PaginatedResponse<StoreProduct>>;
/**
 * Get a single product by slug or ID.
 */
declare function getProduct(slugOrId: string, params?: {
    includes?: string;
}, options?: SpreeNextOptions): Promise<StoreProduct>;
/**
 * Get available product filters (price ranges, option values, etc.).
 */
declare function getProductFilters(params?: Record<string, unknown>, options?: SpreeNextOptions): Promise<ProductFiltersResponse>;

export { getProduct, getProductFilters, listProducts };
