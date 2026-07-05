import type { InternalRequestOptions, RequestConfig, RequestFn, RetryConfig } from '@spree/sdk-core'
import { createRequestFn, resolveRetryConfig, SpreeError } from '@spree/sdk-core'
import { AdminClient } from './admin-client'

export interface AdminClientConfig {
  /** Base URL of the Spree API (e.g., 'https://api.mystore.com'). Use '' for relative URLs (Vite proxy). */
  baseUrl: string
  /** Secret API key for server-to-server integrations (mutually exclusive with jwtToken) */
  secretKey?: string
  /** JWT token for admin SPA sessions (mutually exclusive with secretKey) */
  jwtToken?: string
  /** Store ID header for multi-store routing (e.g., 'store_k5nR8xLq') */
  storeId?: string
  /** Custom fetch implementation (optional, defaults to global fetch) */
  fetch?: typeof fetch
  /** Retry configuration. Enabled by default. Pass false to disable. */
  retry?: RetryConfig | false
  /**
   * Credentials mode for cross-origin requests. Defaults to `'include'` so the
   * admin refresh-token cookie is sent on `/api/v3/admin/auth/*`. Override when
   * embedding in environments where cookies should not flow.
   */
  credentials?: RequestCredentials
}

export interface Client extends AdminClient {
  /** Set or change the target store for subsequent requests (multi-store routing) */
  setStore(storeId: string): void
  /** Set JWT token for authenticated admin sessions */
  setToken(token: string): void
  /**
   * Register a callback that fires on 401 responses.
   * Return `true` to retry the original request (after refreshing the token via setToken).
   * Return `false` to let the error propagate.
   */
  onUnauthorized(handler: () => Promise<boolean>): void
}

export function createAdminClient(config: AdminClientConfig): Client {
  const baseUrl = config.baseUrl.replace(/\/$/, '')
  const fetchFn = config.fetch || fetch.bind(globalThis)
  const retryConfig = resolveRetryConfig(config.retry)
  const requestConfig: RequestConfig = {
    baseUrl,
    fetchFn,
    retryConfig,
    credentials: config.credentials ?? 'include',
  }

  let currentToken = config.jwtToken
  let currentStoreId = config.storeId
  let unauthorizedHandler: (() => Promise<boolean>) | null = null

  const basePath = '/api/v3/admin'

  const dynamicRequestFn: RequestFn = async <T>(
    method: string,
    path: string,
    options: InternalRequestOptions = {},
  ): Promise<T> => {
    const extraHeaders: Record<string, string> = {}
    if (currentStoreId) {
      extraHeaders['X-Spree-Store-Id'] = currentStoreId
    }

    const mergedOptions: InternalRequestOptions = {
      ...options,
      headers: {
        ...extraHeaders,
        ...options.headers,
      },
    }

    const makeRequest = () => {
      // Secret keys go in `X-Spree-Api-Key` (server-to-server integrations).
      // JWT tokens go in `Authorization: Bearer` (admin SPA sessions).
      const auth = config.secretKey
        ? { headerName: 'X-Spree-Api-Key', headerValue: config.secretKey }
        : { headerName: 'Authorization', headerValue: currentToken ? `Bearer ${currentToken}` : '' }
      const requestFn = createRequestFn(requestConfig, basePath, auth)
      return requestFn<T>(method, path, mergedOptions)
    }

    try {
      return await makeRequest()
    } catch (error) {
      // On 401, try the unauthorized handler (token refresh) and retry once
      if (
        error instanceof SpreeError &&
        error.status === 401 &&
        unauthorizedHandler &&
        !path.includes('/auth/') // Don't retry auth endpoints
      ) {
        const shouldRetry = await unauthorizedHandler()
        if (shouldRetry) {
          return makeRequest()
        }
      }
      throw error
    }
  }

  const adminClient = new AdminClient(dynamicRequestFn)
  const client = Object.create(adminClient) as Client

  client.setStore = (storeId: string) => {
    currentStoreId = storeId
  }

  client.setToken = (token: string) => {
    currentToken = token
  }

  client.onUnauthorized = (handler: () => Promise<boolean>) => {
    unauthorizedHandler = handler
  }

  return client
}
