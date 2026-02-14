import { createSpreeClient, type SpreeClient } from '@spree/sdk';
import type { SpreeNextConfig } from './types';

let _client: SpreeClient | null = null;
let _config: SpreeNextConfig | null = null;

/**
 * Initialize the Spree Next.js integration.
 * Call this once in your app (e.g., in `lib/storefront.ts`).
 * If not called, the client will auto-initialize from SPREE_API_URL and SPREE_PUBLISHABLE_KEY env vars.
 */
export function initSpreeNext(config: SpreeNextConfig): void {
  _config = config;
  _client = createSpreeClient({
    baseUrl: config.baseUrl,
    publishableKey: config.publishableKey,
  });
}

/**
 * Get the SpreeClient instance. Auto-initializes from env vars if needed.
 * @internal
 */
export function getClient(): SpreeClient {
  if (!_client) {
    const baseUrl = process.env.SPREE_API_URL;
    const publishableKey = process.env.SPREE_PUBLISHABLE_KEY;
    if (baseUrl && publishableKey) {
      initSpreeNext({ baseUrl, publishableKey });
    } else {
      throw new Error(
        '@spree/next is not configured. Either call initSpreeNext() or set SPREE_API_URL and SPREE_PUBLISHABLE_KEY environment variables.'
      );
    }
  }
  return _client!;
}

/**
 * Get the current config. Auto-initializes from env vars if needed.
 * @internal
 */
export function getConfig(): SpreeNextConfig {
  if (!_config) {
    getClient(); // triggers auto-init
  }
  return _config!;
}

/**
 * Reset the client (useful for testing).
 * @internal
 */
export function resetClient(): void {
  _client = null;
  _config = null;
}
