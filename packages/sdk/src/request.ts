import type { ErrorResponse } from './types';

export interface RetryConfig {
  /** Maximum number of retries (default: 2) */
  maxRetries?: number;
  /** HTTP status codes to retry on (default: [429, 500, 502, 503, 504]) */
  retryOnStatus?: number[];
  /** Base delay in ms for exponential backoff (default: 300) */
  baseDelay?: number;
  /** Maximum delay in ms (default: 10000) */
  maxDelay?: number;
  /** Whether to retry on network errors (default: true) */
  retryOnNetworkError?: boolean;
}

export interface RequestOptions {
  /** Bearer token for authenticated requests */
  token?: string;
  /** Order token for guest checkout */
  orderToken?: string;
  /** Locale for translated content (e.g., 'en', 'fr') */
  locale?: string;
  /** Currency for prices (e.g., 'USD', 'EUR') */
  currency?: string;
  /** Custom headers */
  headers?: Record<string, string>;
}

export interface InternalRequestOptions extends RequestOptions {
  body?: unknown;
  params?: Record<string, string | number | undefined>;
}

export class SpreeError extends Error {
  public readonly code: string;
  public readonly status: number;
  public readonly details?: Record<string, string[]>;

  constructor(response: ErrorResponse, status: number) {
    super(response.error.message);
    this.name = 'SpreeError';
    this.code = response.error.code;
    this.status = status;
    this.details = response.error.details;
  }
}

export type RequestFn = <T>(
  method: string,
  path: string,
  options?: InternalRequestOptions
) => Promise<T>;

function calculateDelay(attempt: number, config: Required<RetryConfig>): number {
  const exponentialDelay = config.baseDelay * Math.pow(2, attempt);
  const jitter = Math.random() * config.baseDelay;
  return Math.min(exponentialDelay + jitter, config.maxDelay);
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function shouldRetryOnStatus(method: string, status: number, config: Required<RetryConfig>): boolean {
  const isIdempotent = method === 'GET' || method === 'HEAD';
  if (isIdempotent) {
    return config.retryOnStatus.includes(status);
  }
  return status === 429;
}

function shouldRetryOnNetworkError(method: string, config: Required<RetryConfig>): boolean {
  if (!config.retryOnNetworkError) return false;
  return method === 'GET' || method === 'HEAD';
}

export interface RequestConfig {
  baseUrl: string;
  fetchFn: typeof fetch;
  retryConfig: Required<RetryConfig> | false;
}

export interface AuthConfig {
  headerName: string;
  headerValue: string;
}

/**
 * Creates a bound request function for a specific API scope (store or admin).
 */
export function createRequestFn(
  config: RequestConfig,
  basePath: string,
  auth: AuthConfig
): RequestFn {
  return async function request<T>(
    method: string,
    path: string,
    options: InternalRequestOptions = {}
  ): Promise<T> {
    const { token, orderToken, locale, currency, headers = {}, body, params } = options;

    // Build URL with query params
    const url = new URL(`${config.baseUrl}${basePath}${path}`);
    if (params) {
      Object.entries(params).forEach(([key, value]) => {
        if (value !== undefined) {
          if (Array.isArray(value)) {
            value.forEach((v) => url.searchParams.append(key, String(v)));
          } else {
            url.searchParams.set(key, String(value));
          }
        }
      });
    }
    if (orderToken) {
      url.searchParams.set('order_token', orderToken);
    }

    // Build headers
    const requestHeaders: Record<string, string> = {
      'Content-Type': 'application/json',
      [auth.headerName]: auth.headerValue,
      ...headers,
    };

    if (token) {
      requestHeaders['Authorization'] = `Bearer ${token}`;
    }

    if (orderToken) {
      requestHeaders['x-spree-order-token'] = orderToken;
    }

    if (locale) {
      requestHeaders['x-spree-locale'] = locale;
    }

    if (currency) {
      requestHeaders['x-spree-currency'] = currency;
    }

    const maxAttempts = config.retryConfig ? config.retryConfig.maxRetries + 1 : 1;

    for (let attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        const response = await config.fetchFn(url.toString(), {
          method,
          headers: requestHeaders,
          body: body ? JSON.stringify(body) : undefined,
        });

        if (!response.ok) {
          const isLastAttempt = attempt >= maxAttempts - 1;

          if (!isLastAttempt && config.retryConfig && shouldRetryOnStatus(method, response.status, config.retryConfig)) {
            const retryAfter = response.headers.get('Retry-After');
            const delay = retryAfter
              ? Math.min(parseInt(retryAfter, 10) * 1000, config.retryConfig.maxDelay)
              : calculateDelay(attempt, config.retryConfig);
            await sleep(delay);
            continue;
          }

          const errorBody = await response.json() as ErrorResponse;
          throw new SpreeError(errorBody, response.status);
        }

        // Handle 204 No Content
        if (response.status === 204) {
          return undefined as T;
        }

        return response.json() as Promise<T>;
      } catch (error) {
        if (error instanceof SpreeError) {
          throw error;
        }

        const isLastAttempt = attempt >= maxAttempts - 1;

        if (!isLastAttempt && config.retryConfig && shouldRetryOnNetworkError(method, config.retryConfig)) {
          const delay = calculateDelay(attempt, config.retryConfig);
          await sleep(delay);
          continue;
        }

        throw error;
      }
    }

    // This should never be reached, but TypeScript needs it
    throw new Error('Unexpected end of retry loop');
  };
}
