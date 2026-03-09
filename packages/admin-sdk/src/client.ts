import { createRequestFn, resolveRetryConfig } from '@spree/sdk-core';
import type { RetryConfig, RequestConfig, RequestFn, InternalRequestOptions } from '@spree/sdk-core';
import { AdminClient } from './admin-client';

export interface AdminClientConfig {
  /** Base URL of the Spree API (e.g., 'https://api.mystore.com') */
  baseUrl: string;
  /** Secret API key for server-to-server integrations (mutually exclusive with jwtToken) */
  secretKey?: string;
  /** JWT token for admin SPA sessions (mutually exclusive with secretKey) */
  jwtToken?: string;
  /** Store ID header for multi-store routing (e.g., 'store_k5nR8xLq') */
  storeId?: string;
  /** Custom fetch implementation (optional, defaults to global fetch) */
  fetch?: typeof fetch;
  /** Retry configuration. Enabled by default. Pass false to disable. */
  retry?: RetryConfig | false;
}

export interface Client extends AdminClient {
  /** Set or change the target store for subsequent requests (multi-store routing) */
  setStore(storeId: string): void;
  /** Set JWT token for authenticated admin sessions */
  setToken(token: string): void;
}

/**
 * Create a new Spree Admin SDK client.
 *
 * Supports two authentication modes:
 * - **Secret key**: For server-to-server integrations (e.g., backend scripts, CI/CD)
 * - **JWT token**: For admin SPA sessions (e.g., custom admin dashboards)
 *
 * ```ts
 * // Server integration with secret key
 * const admin = createAdminClient({
 *   baseUrl: 'https://api.mystore.com',
 *   secretKey: 'spree_sk_xxx',
 * })
 *
 * // Admin SPA with JWT
 * const admin = createAdminClient({
 *   baseUrl: 'https://api.mystore.com',
 *   jwtToken: 'eyJ...',
 *   storeId: 'store_k5nR8xLq',
 * })
 * ```
 */
export function createAdminClient(config: AdminClientConfig): Client {
  if (!config.secretKey && !config.jwtToken) {
    throw new Error('Admin client requires either secretKey or jwtToken');
  }

  const baseUrl = config.baseUrl.replace(/\/$/, '');
  const fetchFn = config.fetch || fetch.bind(globalThis);
  const retryConfig = resolveRetryConfig(config.retry);
  const requestConfig: RequestConfig = { baseUrl, fetchFn, retryConfig };

  // Mutable state for token and store switching
  let currentToken = config.jwtToken;
  let currentStoreId = config.storeId;

  const basePath = '/api/v3/admin';

  // Dynamic request function that reads current token/storeId on each call
  const dynamicRequestFn: RequestFn = async <T>(
    method: string,
    path: string,
    options: InternalRequestOptions = {}
  ): Promise<T> => {
    const authValue = config.secretKey
      ? `Bearer ${config.secretKey}`
      : currentToken
        ? `Bearer ${currentToken}`
        : '';

    const extraHeaders: Record<string, string> = {};
    if (currentStoreId) {
      extraHeaders['X-Spree-Store-Id'] = currentStoreId;
    }

    const mergedOptions: InternalRequestOptions = {
      ...options,
      headers: {
        ...extraHeaders,
        ...options.headers,
      },
    };

    const requestFn = createRequestFn(
      requestConfig,
      basePath,
      { headerName: 'Authorization', headerValue: authValue },
    );

    return requestFn<T>(method, path, mergedOptions);
  };

  const adminClient = new AdminClient(dynamicRequestFn);
  const client = Object.create(adminClient) as Client;

  client.setStore = (storeId: string) => {
    currentStoreId = storeId;
  };

  client.setToken = (token: string) => {
    currentToken = token;
  };

  return client;
}
