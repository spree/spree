import type { InternalRequestOptions, RequestConfig, RequestFn, RetryConfig } from '@spree/sdk-core'
import { createRequestFn, resolveRetryConfig, SpreeError } from '@spree/sdk-core'
import { SellerClient } from './seller-client'

export interface SellerClientConfig {
  /** Base URL of the Spree API (e.g., 'https://api.mystore.com'). Use '' for relative URLs (Vite proxy). */
  baseUrl: string
  /**
   * JWT token for seller panel sessions. There is deliberately no secret-key
   * equivalent: the Seller API has no server-to-server credential, because a
   * key that acts as a seller without a seller signing in is exactly what the
   * `seller_api` audience exists to prevent.
   */
  jwtToken?: string
  /**
   * Which seller the signed-in user is acting as. Sent as `X-Spree-Seller-Id`; the
   * store is derived from the seller server-side, never sent alongside, so no
   * header here can widen what the seller reaches.
   */
  sellerId?: string
  /** Custom fetch implementation (optional, defaults to global fetch) */
  fetch?: typeof fetch
  /** Retry configuration. Enabled by default. Pass false to disable. */
  retry?: RetryConfig | false
  /**
   * Credentials mode for cross-origin requests. Defaults to `'include'` so the
   * seller refresh-token cookie is sent on `/api/v3/seller/auth/*`. That cookie
   * has its own name and path — sharing either would let a session issued for
   * one panel be redeemed on the other.
   */
  credentials?: RequestCredentials
}

export interface Client extends SellerClient {
  /** Set or change which seller the signed-in user is acting as. */
  setSeller(sellerId: string): void
  /** Set the JWT for an authenticated seller session. */
  setToken(token: string): void
  /**
   * Register a callback that fires on 401 responses.
   * Return `true` to retry the original request (after refreshing the token via setToken).
   * Return `false` to let the error propagate.
   */
  onUnauthorized(handler: () => Promise<boolean>): void
}

export function createSellerClient(config: SellerClientConfig): Client {
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
  let currentSellerId = config.sellerId
  let unauthorizedHandler: (() => Promise<boolean>) | null = null

  const basePath = '/api/v3/seller'

  const dynamicRequestFn: RequestFn = async <T>(
    method: string,
    path: string,
    options: InternalRequestOptions = {},
  ): Promise<T> => {
    const extraHeaders: Record<string, string> = {}
    // Auth endpoints run before a seller is chosen — `/me` is what tells the
    // panel which sellers the user may act for — so a stale id from a
    // previous session must never be able to 403 the way back in.
    if (currentSellerId && !path.startsWith('/auth/')) {
      extraHeaders['X-Spree-Seller-Id'] = currentSellerId
    }

    const mergedOptions: InternalRequestOptions = {
      ...options,
      headers: {
        ...extraHeaders,
        ...options.headers,
      },
    }

    const makeRequest = () => {
      const requestFn = createRequestFn(requestConfig, basePath, {
        headerName: 'Authorization',
        headerValue: currentToken ? `Bearer ${currentToken}` : '',
      })
      return requestFn<T>(method, path, mergedOptions)
    }

    try {
      return await makeRequest()
    } catch (error) {
      if (
        error instanceof SpreeError &&
        error.status === 401 &&
        unauthorizedHandler &&
        !path.includes('/auth/')
      ) {
        const shouldRetry = await unauthorizedHandler()
        if (shouldRetry) {
          return makeRequest()
        }
      }
      throw error
    }
  }

  const sellerClient = new SellerClient(dynamicRequestFn)
  const client = Object.create(sellerClient) as Client

  client.setSeller = (sellerId: string) => {
    currentSellerId = sellerId
  }

  client.setToken = (token: string) => {
    currentToken = token
  }

  client.onUnauthorized = (handler: () => Promise<boolean>) => {
    unauthorizedHandler = handler
  }

  return client
}
