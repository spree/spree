import { StoreStore } from '@spree/sdk';
import { SpreeNextOptions } from '../types.js';

/**
 * Get the current store configuration.
 */
declare function getStore(options?: SpreeNextOptions): Promise<StoreStore>;

export { getStore };
