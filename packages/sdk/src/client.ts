import type {
  AuthTokens,
  LoginCredentials,
  RegisterParams,
  ErrorResponse,
  PaginatedResponse,
  ListParams,
  ProductListParams,
  ProductFiltersParams,
  ProductFiltersResponse,
  TaxonListParams,
  OrderListParams,
  AddLineItemParams,
  UpdateLineItemParams,
  UpdateOrderParams,
  AddressParams,
  StoreCreditCard,
  StoreGiftCard,
  StoreProduct,
  StoreOrder,
  StoreLineItem,
  StoreCountry,
  StoreTaxonomy,
  StoreTaxon,
  StorePayment,
  StorePaymentMethod,
  StoreShipment,
  StoreStore,
  StoreWishlist,
  StoreWishedItem,
  StoreAddress,
  StoreCustomer,
} from './types';

// Re-export types for convenience
export type { AddressParams, StoreCreditCard };

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

export interface SpreeClientConfig {
  /** Base URL of the Spree API (e.g., 'https://api.mystore.com') */
  baseUrl: string;
  /** Publishable API key for store access */
  apiKey: string;
  /** Custom fetch implementation (optional, defaults to global fetch) */
  fetch?: typeof fetch;
  /** Retry configuration. Enabled by default. Pass false to disable. */
  retry?: RetryConfig | false;
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

export class SpreeClient {
  private readonly baseUrl: string;
  private readonly apiKey: string;
  private readonly fetchFn: typeof fetch;
  private readonly retryConfig: Required<RetryConfig> | false;

  constructor(config: SpreeClientConfig) {
    this.baseUrl = config.baseUrl.replace(/\/$/, '');
    this.apiKey = config.apiKey;
    // Bind fetch to globalThis to avoid "Illegal invocation" errors in browsers
    this.fetchFn = config.fetch || fetch.bind(globalThis);

    if (config.retry === false) {
      this.retryConfig = false;
    } else {
      this.retryConfig = {
        maxRetries: config.retry?.maxRetries ?? 2,
        retryOnStatus: config.retry?.retryOnStatus ?? [429, 500, 502, 503, 504],
        baseDelay: config.retry?.baseDelay ?? 300,
        maxDelay: config.retry?.maxDelay ?? 10000,
        retryOnNetworkError: config.retry?.retryOnNetworkError ?? true,
      };
    }
  }

  private calculateDelay(attempt: number, config: Required<RetryConfig>): number {
    const exponentialDelay = config.baseDelay * Math.pow(2, attempt);
    const jitter = Math.random() * config.baseDelay;
    return Math.min(exponentialDelay + jitter, config.maxDelay);
  }

  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  private shouldRetryOnStatus(method: string, status: number, config: Required<RetryConfig>): boolean {
    const isIdempotent = method === 'GET' || method === 'HEAD';
    // Idempotent methods: retry on all configured statuses
    // Non-idempotent: only retry on 429 (rate limit)
    if (isIdempotent) {
      return config.retryOnStatus.includes(status);
    }
    return status === 429;
  }

  private shouldRetryOnNetworkError(method: string, config: Required<RetryConfig>): boolean {
    if (!config.retryOnNetworkError) return false;
    return method === 'GET' || method === 'HEAD';
  }

  private async request<T>(
    method: string,
    path: string,
    options: RequestOptions & {
      body?: unknown;
      params?: Record<string, string | number | undefined>;
    } = {}
  ): Promise<T> {
    const { token, orderToken, locale, currency, headers = {}, body, params } = options;

    // Build URL with query params
    const url = new URL(`${this.baseUrl}/api/v3/store${path}`);
    if (params) {
      Object.entries(params).forEach(([key, value]) => {
        if (value !== undefined) {
          // Handle arrays by appending each value with the same key (Rails-style)
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
      'x-spree-api-key': this.apiKey,
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

    const maxAttempts = this.retryConfig ? this.retryConfig.maxRetries + 1 : 1;

    for (let attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        const response = await this.fetchFn(url.toString(), {
          method,
          headers: requestHeaders,
          body: body ? JSON.stringify(body) : undefined,
        });

        if (!response.ok) {
          const isLastAttempt = attempt >= maxAttempts - 1;

          if (!isLastAttempt && this.retryConfig && this.shouldRetryOnStatus(method, response.status, this.retryConfig)) {
            const retryAfter = response.headers.get('Retry-After');
            const delay = retryAfter
              ? Math.min(parseInt(retryAfter, 10) * 1000, this.retryConfig.maxDelay)
              : this.calculateDelay(attempt, this.retryConfig);
            await this.sleep(delay);
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

        if (!isLastAttempt && this.retryConfig && this.shouldRetryOnNetworkError(method, this.retryConfig)) {
          const delay = this.calculateDelay(attempt, this.retryConfig);
          await this.sleep(delay);
          continue;
        }

        throw error;
      }
    }

    // This should never be reached, but TypeScript needs it
    throw new Error('Unexpected end of retry loop');
  }

  // ============================================
  // Authentication
  // ============================================

  readonly auth = {
    /**
     * Login with email and password
     */
    login: (credentials: LoginCredentials): Promise<AuthTokens> =>
      this.request<AuthTokens>('POST', '/auth/login', { body: credentials }),

    /**
     * Register a new customer account
     */
    register: (params: RegisterParams): Promise<AuthTokens> =>
      this.request<AuthTokens>('POST', '/auth/register', { body: params }),

    /**
     * Refresh access token (requires valid Bearer token)
     */
    refresh: (options: RequestOptions): Promise<AuthTokens> =>
      this.request<AuthTokens>('POST', '/auth/refresh', options),
  };

  // ============================================
  // Store
  // ============================================

  readonly store = {
    /**
     * Get current store information
     */
    get: (options?: RequestOptions): Promise<StoreStore> =>
      this.request<StoreStore>('GET', '/store', options),
  };

  // ============================================
  // Products
  // ============================================

  readonly products = {
    /**
     * List products
     */
    list: (
      params?: ProductListParams,
      options?: RequestOptions
    ): Promise<PaginatedResponse<StoreProduct>> =>
      this.request<PaginatedResponse<StoreProduct>>('GET', '/products', {
        ...options,
        params: params as Record<string, string | number | undefined>,
      }),

    /**
     * Get a product by ID or slug
     */
    get: (
      idOrSlug: string,
      params?: { includes?: string },
      options?: RequestOptions
    ): Promise<StoreProduct> =>
      this.request<StoreProduct>('GET', `/products/${idOrSlug}`, {
        ...options,
        params,
      }),

    /**
     * Get available filters for products
     * Returns filter options (price range, availability, option types, taxons) with counts
     */
    filters: (
      params?: ProductFiltersParams,
      options?: RequestOptions
    ): Promise<ProductFiltersResponse> =>
      this.request<ProductFiltersResponse>('GET', '/products/filters', {
        ...options,
        params: params as Record<string, string | number | undefined>,
      }),
  };

  // ============================================
  // Taxonomies & Taxons
  // ============================================

  readonly taxonomies = {
    /**
     * List taxonomies
     */
    list: (
      params?: ListParams,
      options?: RequestOptions
    ): Promise<PaginatedResponse<StoreTaxonomy>> =>
      this.request<PaginatedResponse<StoreTaxonomy>>('GET', '/taxonomies', {
        ...options,
        params: params as Record<string, string | number | undefined>,
      }),

    /**
     * Get a taxonomy by ID
     */
    get: (
      id: string,
      params?: { includes?: string },
      options?: RequestOptions
    ): Promise<StoreTaxonomy> =>
      this.request<StoreTaxonomy>('GET', `/taxonomies/${id}`, {
        ...options,
        params,
      }),
  };

  readonly taxons = {
    /**
     * List taxons
     */
    list: (
      params?: TaxonListParams,
      options?: RequestOptions
    ): Promise<PaginatedResponse<StoreTaxon>> =>
      this.request<PaginatedResponse<StoreTaxon>>('GET', '/taxons', {
        ...options,
        params: params as Record<string, string | number | undefined>,
      }),

    /**
     * Get a taxon by ID or permalink
     */
    get: (
      idOrPermalink: string,
      params?: { includes?: string },
      options?: RequestOptions
    ): Promise<StoreTaxon> =>
      this.request<StoreTaxon>('GET', `/taxons/${idOrPermalink}`, {
        ...options,
        params,
      }),

    /**
     * Nested resource: Products in a taxon
     */
    products: {
      /**
       * List products in a taxon
       * @param taxonId - Taxon ID (prefix_id) or permalink
       */
      list: (
        taxonId: string,
        params?: ProductListParams,
        options?: RequestOptions
      ): Promise<PaginatedResponse<StoreProduct>> =>
        this.request<PaginatedResponse<StoreProduct>>(
          'GET',
          `/taxons/${taxonId}/products`,
          {
            ...options,
            params: params as Record<string, string | number | undefined>,
          }
        ),
    },
  };

  // ============================================
  // Geography
  // ============================================

  readonly countries = {
    /**
     * List countries available for checkout
     * Returns countries from the store's checkout zone without states
     */
    list: (options?: RequestOptions): Promise<{ data: StoreCountry[] }> =>
      this.request<{ data: StoreCountry[] }>('GET', '/countries', options),

    /**
     * Get a country by ISO code with states
     * @param iso - ISO 3166-1 alpha-2 code (e.g., "US", "DE")
     */
    get: (iso: string, options?: RequestOptions): Promise<StoreCountry> =>
      this.request<StoreCountry>('GET', `/countries/${iso}`, options),
  };

  // ============================================
  // Cart (convenience wrapper for current incomplete order)
  // ============================================

  readonly cart = {
    /**
     * Get current cart (returns null if none exists)
     * Pass orderToken for guest checkout, or use JWT for authenticated users
     */
    get: (options?: RequestOptions): Promise<StoreOrder & { token: string }> =>
      this.request<StoreOrder & { token: string }>('GET', '/cart', options),

    /**
     * Create a new cart (alias for orders.create)
     */
    create: (options?: RequestOptions): Promise<StoreOrder & { token: string }> =>
      this.request<StoreOrder & { token: string }>('POST', '/orders', options),

    /**
     * Associate a guest cart with the currently authenticated user
     * Requires both JWT token (for authentication) and orderToken (to identify the cart)
     * @param options - Must include both `token` (JWT) and `orderToken` (guest cart token)
     */
    associate: (options: RequestOptions): Promise<StoreOrder & { token: string }> =>
      this.request<StoreOrder & { token: string }>('PATCH', '/cart/associate', options),
  };

  // ============================================
  // Orders (all orders - complete and incomplete)
  // ============================================

  readonly orders = {
    /**
     * List orders for the authenticated customer
     */
    list: (
      params?: OrderListParams,
      options?: RequestOptions
    ): Promise<PaginatedResponse<StoreOrder>> =>
      this.request<PaginatedResponse<StoreOrder>>('GET', '/orders', {
        ...options,
        params: params as Record<string, string | number | undefined>,
      }),

    /**
     * Create a new order (cart)
     */
    create: (options?: RequestOptions): Promise<StoreOrder & { order_token: string }> =>
      this.request<StoreOrder & { order_token: string }>('POST', '/orders', options),

    /**
     * Get an order by ID or number
     */
    get: (
      idOrNumber: string,
      params?: { includes?: string },
      options?: RequestOptions
    ): Promise<StoreOrder> =>
      this.request<StoreOrder>('GET', `/orders/${idOrNumber}`, {
        ...options,
        params,
      }),

    /**
     * Update an order
     */
    update: (
      idOrNumber: string,
      params: UpdateOrderParams,
      options?: RequestOptions
    ): Promise<StoreOrder> =>
      this.request<StoreOrder>('PATCH', `/orders/${idOrNumber}`, {
        ...options,
        body: params,
      }),

    /**
     * Advance order to next checkout step
     */
    next: (idOrNumber: string, options?: RequestOptions): Promise<StoreOrder> =>
      this.request<StoreOrder>('PATCH', `/orders/${idOrNumber}/next`, options),

    /**
     * Advance through all checkout steps
     */
    advance: (idOrNumber: string, options?: RequestOptions): Promise<StoreOrder> =>
      this.request<StoreOrder>('PATCH', `/orders/${idOrNumber}/advance`, options),

    /**
     * Complete the order
     */
    complete: (idOrNumber: string, options?: RequestOptions): Promise<StoreOrder> =>
      this.request<StoreOrder>('PATCH', `/orders/${idOrNumber}/complete`, options),

    /**
     * Add store credit to order
     */
    addStoreCredit: (
      idOrNumber: string,
      amount?: number,
      options?: RequestOptions
    ): Promise<StoreOrder> =>
      this.request<StoreOrder>('POST', `/orders/${idOrNumber}/store_credits`, {
        ...options,
        body: amount ? { amount } : undefined,
      }),

    /**
     * Remove store credit from order
     */
    removeStoreCredit: (
      idOrNumber: string,
      options?: RequestOptions
    ): Promise<StoreOrder> =>
      this.request<StoreOrder>('DELETE', `/orders/${idOrNumber}/store_credits`, options),

    /**
     * Nested resource: Line items
     */
    lineItems: {
      /**
       * Add a line item to an order
       */
      create: (
        orderId: string,
        params: AddLineItemParams,
        options?: RequestOptions
      ): Promise<StoreLineItem> =>
        this.request<StoreLineItem>('POST', `/orders/${orderId}/line_items`, {
          ...options,
          body: params,
        }),

      /**
       * Update a line item
       */
      update: (
        orderId: string,
        lineItemId: string,
        params: UpdateLineItemParams,
        options?: RequestOptions
      ): Promise<StoreLineItem> =>
        this.request<StoreLineItem>(
          'PATCH',
          `/orders/${orderId}/line_items/${lineItemId}`,
          { ...options, body: params }
        ),

      /**
       * Remove a line item from an order
       */
      delete: (
        orderId: string,
        lineItemId: string,
        options?: RequestOptions
      ): Promise<void> =>
        this.request<void>(
          'DELETE',
          `/orders/${orderId}/line_items/${lineItemId}`,
          options
        ),
    },

    /**
     * Nested resource: Payments
     */
    payments: {
      /**
       * List payments for an order
       */
      list: (
        orderId: string,
        options?: RequestOptions
      ): Promise<{ data: StorePayment[]; meta: object }> =>
        this.request<{ data: StorePayment[]; meta: object }>(
          'GET',
          `/orders/${orderId}/payments`,
          options
        ),

      /**
       * Get a payment by ID
       */
      get: (
        orderId: string,
        paymentId: string,
        options?: RequestOptions
      ): Promise<StorePayment> =>
        this.request<StorePayment>(
          'GET',
          `/orders/${orderId}/payments/${paymentId}`,
          options
        ),
    },

    /**
     * Nested resource: Payment methods
     */
    paymentMethods: {
      /**
       * List available payment methods for an order
       */
      list: (
        orderId: string,
        options?: RequestOptions
      ): Promise<PaginatedResponse<StorePaymentMethod>> =>
        this.request<PaginatedResponse<StorePaymentMethod>>(
          'GET',
          `/orders/${orderId}/payment_methods`,
          options
        ),
    },

    /**
     * Nested resource: Coupon codes
     */
    couponCodes: {
      /**
       * Apply a coupon code to an order
       */
      apply: (
        orderId: string,
        code: string,
        options?: RequestOptions
      ): Promise<StoreOrder> =>
        this.request<StoreOrder>('POST', `/orders/${orderId}/coupon_codes`, {
          ...options,
          body: { code },
        }),

      /**
       * Remove a coupon code from an order
       * @param promotionId - The promotion prefix_id (e.g., 'promo_xxx')
       */
      remove: (
        orderId: string,
        promotionId: string,
        options?: RequestOptions
      ): Promise<StoreOrder> =>
        this.request<StoreOrder>(
          'DELETE',
          `/orders/${orderId}/coupon_codes/${promotionId}`,
          options
        ),
    },

    /**
     * Nested resource: Shipments
     */
    shipments: {
      /**
       * List shipments for an order
       */
      list: (
        orderId: string,
        options?: RequestOptions
      ): Promise<{ data: StoreShipment[] }> =>
        this.request<{ data: StoreShipment[] }>(
          'GET',
          `/orders/${orderId}/shipments`,
          options
        ),

      /**
       * Update a shipment (e.g., select shipping rate)
       */
      update: (
        orderId: string,
        shipmentId: string,
        params: { selected_shipping_rate_id: string },
        options?: RequestOptions
      ): Promise<StoreShipment> =>
        this.request<StoreShipment>(
          'PATCH',
          `/orders/${orderId}/shipments/${shipmentId}`,
          { ...options, body: params }
        ),
    },
  };

  // ============================================
  // Customer
  // ============================================

  readonly customer = {
    /**
     * Get current customer profile
     */
    get: (options?: RequestOptions): Promise<StoreCustomer> =>
      this.request<StoreCustomer>('GET', '/customer', options),

    /**
     * Update current customer profile
     */
    update: (
      params: { first_name?: string; last_name?: string; email?: string },
      options?: RequestOptions
    ): Promise<StoreCustomer> =>
      this.request<StoreCustomer>('PATCH', '/customer', {
        ...options,
        body: params,
      }),

    /**
     * Nested resource: Addresses
     */
    addresses: {
      /**
       * List customer addresses
       */
      list: (
        params?: ListParams,
        options?: RequestOptions
      ): Promise<PaginatedResponse<StoreAddress>> =>
        this.request<PaginatedResponse<StoreAddress>>(
          'GET',
          '/customer/addresses',
          { ...options, params: params as Record<string, string | number | undefined> }
        ),

      /**
       * Get an address by ID
       */
      get: (id: string, options?: RequestOptions): Promise<StoreAddress> =>
        this.request<StoreAddress>('GET', `/customer/addresses/${id}`, options),

      /**
       * Create an address
       */
      create: (
        params: AddressParams,
        options?: RequestOptions
      ): Promise<StoreAddress> =>
        this.request<StoreAddress>('POST', '/customer/addresses', {
          ...options,
          body: params,
        }),

      /**
       * Update an address
       */
      update: (
        id: string,
        params: Partial<AddressParams>,
        options?: RequestOptions
      ): Promise<StoreAddress> =>
        this.request<StoreAddress>('PATCH', `/customer/addresses/${id}`, {
          ...options,
          body: params,
        }),

      /**
       * Delete an address
       */
      delete: (id: string, options?: RequestOptions): Promise<void> =>
        this.request<void>('DELETE', `/customer/addresses/${id}`, options),
    },

    /**
     * Nested resource: Credit Cards
     */
    creditCards: {
      /**
       * List customer credit cards
       */
      list: (
        params?: ListParams,
        options?: RequestOptions
      ): Promise<PaginatedResponse<StoreCreditCard>> =>
        this.request<PaginatedResponse<StoreCreditCard>>(
          'GET',
          '/customer/credit_cards',
          { ...options, params: params as Record<string, string | number | undefined> }
        ),

      /**
       * Get a credit card by ID
       */
      get: (id: string, options?: RequestOptions): Promise<StoreCreditCard> =>
        this.request<StoreCreditCard>('GET', `/customer/credit_cards/${id}`, options),

      /**
       * Delete a credit card
       */
      delete: (id: string, options?: RequestOptions): Promise<void> =>
        this.request<void>('DELETE', `/customer/credit_cards/${id}`, options),
    },

    /**
     * Nested resource: Gift Cards
     */
    giftCards: {
      /**
       * List customer gift cards
       * Returns gift cards associated with the current user, ordered by newest first
       */
      list: (
        params?: ListParams,
        options?: RequestOptions
      ): Promise<PaginatedResponse<StoreGiftCard>> =>
        this.request<PaginatedResponse<StoreGiftCard>>(
          'GET',
          '/customer/gift_cards',
          { ...options, params: params as Record<string, string | number | undefined> }
        ),

      /**
       * Get a gift card by ID
       */
      get: (id: string, options?: RequestOptions): Promise<StoreGiftCard> =>
        this.request<StoreGiftCard>('GET', `/customer/gift_cards/${id}`, options),
    },
  };

  // ============================================
  // Wishlists
  // ============================================

  readonly wishlists = {
    /**
     * List wishlists
     */
    list: (
      params?: ListParams,
      options?: RequestOptions
    ): Promise<PaginatedResponse<StoreWishlist>> =>
      this.request<PaginatedResponse<StoreWishlist>>('GET', '/wishlists', {
        ...options,
        params: params as Record<string, string | number | undefined>,
      }),

    /**
     * Get a wishlist by ID
     */
    get: (
      id: string,
      params?: { includes?: string },
      options?: RequestOptions
    ): Promise<StoreWishlist> =>
      this.request<StoreWishlist>('GET', `/wishlists/${id}`, {
        ...options,
        params,
      }),

    /**
     * Create a wishlist
     */
    create: (
      params: { name: string; is_private?: boolean; is_default?: boolean },
      options?: RequestOptions
    ): Promise<StoreWishlist> =>
      this.request<StoreWishlist>('POST', '/wishlists', {
        ...options,
        body: params,
      }),

    /**
     * Update a wishlist
     */
    update: (
      id: string,
      params: { name?: string; is_private?: boolean; is_default?: boolean },
      options?: RequestOptions
    ): Promise<StoreWishlist> =>
      this.request<StoreWishlist>('PATCH', `/wishlists/${id}`, {
        ...options,
        body: params,
      }),

    /**
     * Delete a wishlist
     */
    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/wishlists/${id}`, options),

    /**
     * Nested resource: Wishlist items
     */
    items: {
      /**
       * Add an item to a wishlist
       */
      create: (
        wishlistId: string,
        params: { variant_id: string; quantity?: number },
        options?: RequestOptions
      ): Promise<StoreWishedItem> =>
        this.request<StoreWishedItem>('POST', `/wishlists/${wishlistId}/items`, {
          ...options,
          body: params,
        }),

      /**
       * Update a wishlist item
       */
      update: (
        wishlistId: string,
        itemId: string,
        params: { quantity: number },
        options?: RequestOptions
      ): Promise<StoreWishedItem> =>
        this.request<StoreWishedItem>(
          'PATCH',
          `/wishlists/${wishlistId}/items/${itemId}`,
          { ...options, body: params }
        ),

      /**
       * Remove an item from a wishlist
       */
      delete: (
        wishlistId: string,
        itemId: string,
        options?: RequestOptions
      ): Promise<void> =>
        this.request<void>(
          'DELETE',
          `/wishlists/${wishlistId}/items/${itemId}`,
          options
        ),
    },
  };
}

/**
 * Create a new Spree SDK client
 */
export function createSpreeClient(config: SpreeClientConfig): SpreeClient {
  return new SpreeClient(config);
}
