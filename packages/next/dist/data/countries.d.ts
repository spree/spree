import { StoreCountry } from '@spree/sdk';
import { SpreeNextOptions } from '../types.js';

/**
 * List all available countries.
 */
declare function listCountries(options?: SpreeNextOptions): Promise<{
    data: StoreCountry[];
}>;
/**
 * Get a single country by ISO code.
 */
declare function getCountry(iso: string, options?: SpreeNextOptions): Promise<StoreCountry>;

export { getCountry, listCountries };
