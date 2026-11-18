import type {
  InternalRequestOptions,
  RequestCompleteEvent,
  RequestConfig,
  RequestFn,
  RetryConfig,
} from '@spree/sdk-core'
import {
  createRequestFn,
  type Extended,
  extendClient,
  resolveRetryConfig,
  SpreeError,
} from '@spree/sdk-core'
import { AdminClient } from './admin-client'
import type { AdminExtension } from './extensions'
import type { AssistantEvent } from './types/assistant'

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
  /**
   * Called after every HTTP attempt, successful or not, with its timing,
   * request ID and bodies. Headers include the credentials, so redact them
   * before storing or displaying anything.
   */
  onRequestComplete?: (event: RequestCompleteEvent) => void
}

export interface Client extends AdminClient {
  /** Set or change the target store for subsequent requests (multi-store routing) */
  setStore(storeId: string): void
  /** The store id requests are currently sent for, as set by `storeId` or `setStore`. */
  getStore(): string | undefined
  /** Set JWT token for authenticated admin sessions */
  setToken(token: string): void
  /**
   * Register a callback that fires on 401 responses.
   * Return `true` to retry the original request (after refreshing the token via setToken).
   * Return `false` to let the error propagate.
   */
  onUnauthorized(handler: () => Promise<boolean>): void
  /**
   * Returns a client with a package's namespace added, built on this one
   * (see `defineAdminExtension`). This client is left as it was; both share
   * its settings, so a token or locale set on either applies to the other.
   *
   * @example
   * ```ts
   * const client = base.extend(quotes)
   * await client.quotes.get('quote_1')
   * ```
   */
  extend<Name extends string, Namespace>(
    extension: AdminExtension<Name, Namespace>,
  ): Extended<this, Name, Namespace>
  /**
   * Streams one assistant turn, calling `onEvent` per server-sent event.
   * Resolves when the stream closes.
   */
  streamAssistantTurn(
    path: string,
    body: Record<string, unknown> | undefined,
    onEvent: (event: AssistantEvent) => void,
    signal?: AbortSignal,
  ): Promise<void>
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
    onRequestComplete: config.onRequestComplete,
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
    // Auth endpoints are store-agnostic by design (login, refresh, setup,
    // invitation acceptance run before or between store selections), and a
    // stale store id from a previous session must never be able to 404 the
    // way back in.
    if (currentStoreId && !path.startsWith('/auth/')) {
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

  client.getStore = () => currentStoreId || undefined

  client.setToken = (token: string) => {
    currentToken = token
  }

  client.onUnauthorized = (handler: () => Promise<boolean>) => {
    unauthorizedHandler = handler
  }

  client.extend = function <Name extends string, Namespace>(
    this: Client,
    extension: AdminExtension<Name, Namespace>,
  ) {
    return extendClient(this, 'admin', dynamicRequestFn, extension)
  } as Client['extend']

  /**
   * Streams one assistant turn.
   *
   * Uses `fetch` rather than `EventSource`, which cannot send an
   * `Authorization` header — and the assistant is JWT-only by design. Lives on
   * the factory rather than the resource because it needs the token and store
   * id that the request layer keeps private.
   */
  client.streamAssistantTurn = async (
    path: string,
    body: Record<string, unknown> | undefined,
    onEvent: (event: AssistantEvent) => void,
    signal?: AbortSignal,
  ): Promise<void> => {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      Accept: 'text/event-stream',
    }
    if (currentStoreId) headers['X-Spree-Store-Id'] = currentStoreId
    if (currentToken) headers.Authorization = `Bearer ${currentToken}`

    const response = await fetchFn(`${baseUrl}${basePath}${path}`, {
      method: 'POST',
      headers,
      body: body ? JSON.stringify(body) : undefined,
      credentials: requestConfig.credentials,
      signal,
    })

    if (!response.ok || !response.body) {
      throw new SpreeError(
        {
          error: {
            message: `Assistant turn failed with status ${response.status}`,
            code: 'assistant_stream_failed',
          },
        },
        response.status,
      )
    }

    const reader = response.body.getReader()
    const decoder = new TextDecoder()
    let buffer = ''

    while (true) {
      const { done, value } = await reader.read()
      if (done) break

      buffer += decoder.decode(value, { stream: true })

      // SSE frames are separated by a blank line; a partial frame stays in the
      // buffer until its terminator arrives.
      const frames = buffer.split('\n\n')
      buffer = frames.pop() ?? ''

      for (const frame of frames) {
        const parsed = parseServerSentEvent(frame)
        if (parsed) onEvent(parsed)
      }
    }
  }

  return client
}

function parseServerSentEvent(frame: string): AssistantEvent | null {
  let eventName: string | undefined
  const dataLines: string[] = []

  for (const line of frame.split('\n')) {
    if (line.startsWith('event:')) eventName = line.slice(6).trim()
    else if (line.startsWith('data:')) dataLines.push(line.slice(5).trim())
  }

  if (!eventName || dataLines.length === 0) return null

  try {
    return {
      event: eventName as AssistantEvent['event'],
      data: JSON.parse(dataLines.join('\n')),
    }
  } catch {
    // A frame we cannot parse is dropped rather than killing the stream.
    return null
  }
}
