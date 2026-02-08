import { SpreeClient } from '@spree/sdk';
import { SpreeNextConfig } from './types.js';

/**
 * Initialize the Spree Next.js integration.
 * Call this once in your app (e.g., in `lib/storefront.ts`).
 * If not called, the client will auto-initialize from SPREE_API_URL and SPREE_API_KEY env vars.
 */
declare function initSpreeNext(config: SpreeNextConfig): void;
/**
 * Get the SpreeClient instance. Auto-initializes from env vars if needed.
 * @internal
 */
declare function getClient(): SpreeClient;
/**
 * Get the current config. Auto-initializes from env vars if needed.
 * @internal
 */
declare function getConfig(): SpreeNextConfig;
/**
 * Reset the client (useful for testing).
 * @internal
 */
declare function resetClient(): void;

export { getClient, getConfig, initSpreeNext, resetClient };
