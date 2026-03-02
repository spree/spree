import { createRequestFn } from './request';
import type { RetryConfig, RequestConfig } from './request';
import type { LocaleDefaults } from './types';
import { StoreClient } from './store-client';
import { AdminClient } from './admin-client';

// Re-export types for convenience
export type { AddressParams, StoreCreditCard, LocaleDefaults } from './types';

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
  /** Default locale for API requests (e.g., 'fr') */
  locale?: string;
  /** Default currency for API requests (e.g., 'EUR') */
  currency?: string;
  /** Default country ISO code for market resolution (e.g., 'FR') */
  country?: string;
}

export class SpreeClient {
  /** Store API — customer-facing endpoints (products, cart, checkout, account) */
  readonly store: StoreClient;
  /** Admin API — administrative endpoints (manage orders, products, settings) */
  readonly admin: AdminClient;

  private readonly _defaults: LocaleDefaults;

  constructor(config: SpreeClientConfig) {
    const baseUrl = config.baseUrl.replace(/\/$/, '');
    // Bind fetch to globalThis to avoid "Illegal invocation" errors in browsers
    const fetchFn = config.fetch || fetch.bind(globalThis);

    this._defaults = {
      locale: config.locale,
      currency: config.currency,
      country: config.country,
    };

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
      { headerName: 'x-spree-api-key', headerValue: config.publishableKey },
      this._defaults
    );

    const adminRequestFn = createRequestFn(
      requestConfig,
      '/api/v3/admin',
      {
        headerName: 'Authorization',
        headerValue: config.secretKey ? `Bearer ${config.secretKey}` : '',
      },
      this._defaults
    );

    this.store = new StoreClient(storeRequestFn);
    this.admin = new AdminClient(adminRequestFn);
  }

  /** Set default locale for all subsequent requests */
  setLocale(locale: string): void {
    this._defaults.locale = locale;
  }

  /** Set default currency for all subsequent requests */
  setCurrency(currency: string): void {
    this._defaults.currency = currency;
  }

  /** Set default country for all subsequent requests */
  setCountry(country: string): void {
    this._defaults.country = country;
  }
}

/**
 * Create a new Spree SDK client
 */
export function createSpreeClient(config: SpreeClientConfig): SpreeClient {
  return new SpreeClient(config);
}
