import type { LocaleDefaults, RequestConfig, RetryConfig } from '@spree/sdk-core'
import { createRequestFn, resolveRetryConfig } from '@spree/sdk-core'
import { StoreClient } from './store-client'

export interface ClientConfig {
  /** Base URL of the Spree API (e.g., 'https://api.mystore.com') */
  baseUrl: string
  /** Publishable API key for Store API access */
  publishableKey: string
  /** Custom fetch implementation (optional, defaults to global fetch) */
  fetch?: typeof fetch
  /** Retry configuration. Enabled by default. Pass false to disable. */
  retry?: RetryConfig | false
  /** Default locale for API requests (e.g., 'fr') */
  locale?: string
  /** Default currency for API requests (e.g., 'EUR') */
  currency?: string
  /** Default country ISO code for market resolution (e.g., 'FR') */
  country?: string
  /** Default channel code (e.g., 'pos', 'wholesale') sent as X-Spree-Channel */
  channel?: string
}

export interface Client extends StoreClient {
  /** Set default locale for all subsequent requests */
  setLocale(locale: string): void
  /** Set default currency for all subsequent requests */
  setCurrency(currency: string): void
  /** Set default country for all subsequent requests */
  setCountry(country: string): void
  /** Set default sales-channel code for all subsequent requests */
  setChannel(channel: string): void
}

/**
 * Create a new Spree Store SDK client.
 *
 * Returns a flat client with all store resources directly accessible:
 * ```ts
 * const client = createClient({ baseUrl: '...', publishableKey: '...' })
 * client.products.list()
 * client.carts.create()
 * client.orders.get('order_1')
 * ```
 */
export function createClient(config: ClientConfig): Client {
  const baseUrl = config.baseUrl.replace(/\/$/, '')
  const fetchFn = config.fetch || fetch.bind(globalThis)

  const defaults: LocaleDefaults = {
    locale: config.locale,
    currency: config.currency,
    country: config.country,
    channel: config.channel,
  }

  const retryConfig = resolveRetryConfig(config.retry)

  const requestConfig: RequestConfig = { baseUrl, fetchFn, retryConfig }

  const requestFn = createRequestFn(
    requestConfig,
    '/api/v3/store',
    { headerName: 'x-spree-api-key', headerValue: config.publishableKey },
    defaults,
  )

  const storeClient = new StoreClient(requestFn)

  // Build the flat client by spreading StoreClient's prototype methods/properties
  // and adding locale/currency/country setters
  const client = Object.create(storeClient) as Client

  client.setLocale = (locale: string) => {
    defaults.locale = locale
  }
  client.setCurrency = (currency: string) => {
    defaults.currency = currency
  }
  client.setCountry = (country: string) => {
    defaults.country = country
  }
  client.setChannel = (channel: string) => {
    defaults.channel = channel
  }

  return client
}
