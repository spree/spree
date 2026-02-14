import { createRequestFn } from './request';
import type { RetryConfig, RequestConfig } from './request';
import { StoreClient } from './store-client';
import { AdminClient } from './admin-client';

// Re-export types for convenience
export type { AddressParams, StoreCreditCard } from './types';

export interface SpreeClientConfig {
  /** Base URL of the Spree API (e.g., 'https://api.mystore.com') */
  baseUrl: string;
  /** Publishable API key for Store API access */
  publishableKey: string;
  /** Secret API key for Admin API access (optional) */
  secretKey?: string;
  /** Custom fetch implementation (optional, defaults to global fetch) */
  fetch?: typeof fetch;
  /** Retry configuration. Enabled by default. Pass false to disable. */
  retry?: RetryConfig | false;
}

export class SpreeClient {
  /** Store API — customer-facing endpoints (products, cart, checkout, account) */
  readonly store: StoreClient;
  /** Admin API — administrative endpoints (manage orders, products, settings) */
  readonly admin: AdminClient;

  constructor(config: SpreeClientConfig) {
    const baseUrl = config.baseUrl.replace(/\/$/, '');
    // Bind fetch to globalThis to avoid "Illegal invocation" errors in browsers
    const fetchFn = config.fetch || fetch.bind(globalThis);

    let retryConfig: Required<RetryConfig> | false;
    if (config.retry === false) {
      retryConfig = false;
    } else {
      retryConfig = {
        maxRetries: config.retry?.maxRetries ?? 2,
        retryOnStatus: config.retry?.retryOnStatus ?? [429, 500, 502, 503, 504],
        baseDelay: config.retry?.baseDelay ?? 300,
        maxDelay: config.retry?.maxDelay ?? 10000,
        retryOnNetworkError: config.retry?.retryOnNetworkError ?? true,
      };
    }

    const requestConfig: RequestConfig = { baseUrl, fetchFn, retryConfig };

    const storeRequestFn = createRequestFn(
      requestConfig,
      '/api/v3/store',
      { headerName: 'x-spree-api-key', headerValue: config.publishableKey }
    );

    const adminRequestFn = createRequestFn(
      requestConfig,
      '/api/v3/admin',
      {
        headerName: 'Authorization',
        headerValue: config.secretKey ? `Bearer ${config.secretKey}` : '',
      }
    );

    this.store = new StoreClient(storeRequestFn);
    this.admin = new AdminClient(adminRequestFn);
  }
}

/**
 * Create a new Spree SDK client
 */
export function createSpreeClient(config: SpreeClientConfig): SpreeClient {
  return new SpreeClient(config);
}
