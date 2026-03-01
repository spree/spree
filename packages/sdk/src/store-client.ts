import type { RequestFn, RequestOptions } from './request';
import { transformListParams } from './params';
import type {
  AuthTokens,
  LoginCredentials,
  RegisterParams,
  PaginatedResponse,
  ListParams,
  ProductListParams,
  ProductFiltersParams,
  ProductFiltersResponse,
  TaxonListParams,
  OrderListParams,
  CreateCartParams,
  AddLineItemParams,
  UpdateLineItemParams,
  UpdateOrderParams,
  AddressParams,
  CreatePaymentSessionParams,
  UpdatePaymentSessionParams,
  CompletePaymentSessionParams,
  CreatePaymentSetupSessionParams,
  CompletePaymentSetupSessionParams,
  StoreCreditCard,
  StoreGiftCard,
  StoreProduct,
  StoreOrder,
  StoreCountry,
  StoreCurrency,
  StoreLocale,
  StoreTaxonomy,
  StoreTaxon,
  StorePayment,
  StorePaymentMethod,
  StorePaymentSession,
  StorePaymentSetupSession,
  StoreShipment,
  StoreStore,
  StoreWishlist,
  StoreWishedItem,
  StoreAddress,
  StoreCustomer,
} from './types';

export class StoreClient {
  private readonly request: RequestFn;

  constructor(request: RequestFn) {
    this.request = request;
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
        params: params ? transformListParams(params) : undefined,
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
        params: params ? transformListParams(params) : undefined,
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
            params: params ? transformListParams(params) : undefined,
          }
        ),
    },
  };

  // ============================================
  // Countries, Currencies & Locales
  // ============================================

  readonly countries = {
    /**
     * List countries available in the store
     * Each country includes currency and default_locale derived from its market
     */
    list: (options?: RequestOptions): Promise<{ data: StoreCountry[] }> =>
      this.request<{ data: StoreCountry[] }>('GET', '/countries', options),

    /**
     * Get a country by ISO code
     * Use `?include=states` to include states for address forms
     * @param iso - ISO 3166-1 alpha-2 code (e.g., "US", "DE")
     */
    get: (
      iso: string,
      params?: { include?: string },
      options?: RequestOptions
    ): Promise<StoreCountry> =>
      this.request<StoreCountry>('GET', `/countries/${iso}`, {
        ...options,
        params,
      }),
  };

  readonly currencies = {
    /**
     * List currencies supported by the store (derived from markets)
     */
    list: (options?: RequestOptions): Promise<{ data: StoreCurrency[] }> =>
      this.request<{ data: StoreCurrency[] }>('GET', '/currencies', options),
  };

  readonly locales = {
    /**
     * List locales supported by the store (derived from markets)
     */
    list: (options?: RequestOptions): Promise<{ data: StoreLocale[] }> =>
      this.request<{ data: StoreLocale[] }>('GET', '/locales', options),
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
     * Create a new cart
     * @param params - Optional cart parameters (e.g., metadata)
     */
    create: (params?: CreateCartParams, options?: RequestOptions): Promise<StoreOrder & { token: string }> =>
      this.request<StoreOrder & { token: string }>('POST', '/cart', {
        ...options,
        body: params,
      }),

    /**
     * Associate a guest cart with the currently authenticated user
     * Requires both JWT token (for authentication) and orderToken (to identify the cart)
     * @param options - Must include both `token` (JWT) and `orderToken` (guest cart token)
     */
    associate: (options: RequestOptions): Promise<StoreOrder & { token: string }> =>
      this.request<StoreOrder & { token: string }>('PATCH', '/cart/associate', options),
  };

  // ============================================
  // Orders (individual order management & checkout)
  // ============================================

  readonly orders = {
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
       * Add a line item to an order.
       * Returns the updated order with recalculated totals.
       */
      create: (
        orderId: string,
        params: AddLineItemParams,
        options?: RequestOptions
      ): Promise<StoreOrder> =>
        this.request<StoreOrder>('POST', `/orders/${orderId}/line_items`, {
          ...options,
          body: params,
        }),

      /**
       * Update a line item quantity.
       * Returns the updated order with recalculated totals.
       */
      update: (
        orderId: string,
        lineItemId: string,
        params: UpdateLineItemParams,
        options?: RequestOptions
      ): Promise<StoreOrder> =>
        this.request<StoreOrder>(
          'PATCH',
          `/orders/${orderId}/line_items/${lineItemId}`,
          { ...options, body: params }
        ),

      /**
       * Remove a line item from an order.
       * Returns the updated order with recalculated totals.
       */
      delete: (
        orderId: string,
        lineItemId: string,
        options?: RequestOptions
      ): Promise<StoreOrder> =>
        this.request<StoreOrder>(
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
     * Nested resource: Payment sessions
     */
    paymentSessions: {
      /**
       * Create a payment session for an order
       * Delegates to the payment gateway to initialize a provider-specific session
       */
      create: (
        orderId: string,
        params: CreatePaymentSessionParams,
        options?: RequestOptions
      ): Promise<StorePaymentSession> =>
        this.request<StorePaymentSession>(
          'POST',
          `/orders/${orderId}/payment_sessions`,
          { ...options, body: params }
        ),

      /**
       * Get a payment session by ID
       */
      get: (
        orderId: string,
        sessionId: string,
        options?: RequestOptions
      ): Promise<StorePaymentSession> =>
        this.request<StorePaymentSession>(
          'GET',
          `/orders/${orderId}/payment_sessions/${sessionId}`,
          options
        ),

      /**
       * Update a payment session
       * Delegates to the payment gateway to sync changes with the provider
       */
      update: (
        orderId: string,
        sessionId: string,
        params: UpdatePaymentSessionParams,
        options?: RequestOptions
      ): Promise<StorePaymentSession> =>
        this.request<StorePaymentSession>(
          'PATCH',
          `/orders/${orderId}/payment_sessions/${sessionId}`,
          { ...options, body: params }
        ),

      /**
       * Complete a payment session
       * Confirms the payment with the provider, triggering capture/authorization
       */
      complete: (
        orderId: string,
        sessionId: string,
        params?: CompletePaymentSessionParams,
        options?: RequestOptions
      ): Promise<StorePaymentSession> =>
        this.request<StorePaymentSession>(
          'PATCH',
          `/orders/${orderId}/payment_sessions/${sessionId}/complete`,
          { ...options, body: params }
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
       * Select a shipping rate for a shipment.
       * Returns the updated order with recalculated totals.
       */
      update: (
        orderId: string,
        shipmentId: string,
        params: { selected_shipping_rate_id: string },
        options?: RequestOptions
      ): Promise<StoreOrder> =>
        this.request<StoreOrder>(
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
      params: {
        first_name?: string
        last_name?: string
        email?: string
        password?: string
        password_confirmation?: string
        accepts_email_marketing?: boolean
        phone?: string
      },
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

      /**
       * Mark an address as default billing or shipping
       */
      markAsDefault: (
        id: string,
        kind: 'billing' | 'shipping',
        options?: RequestOptions
      ): Promise<StoreAddress> =>
        this.request<StoreAddress>('PATCH', `/customer/addresses/${id}/mark_as_default`, {
          ...options,
          body: { kind },
        }),
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

    /**
     * Nested resource: Orders (customer order history)
     */
    orders: {
      /**
       * List orders for the authenticated customer
       */
      list: (
        params?: OrderListParams,
        options?: RequestOptions
      ): Promise<PaginatedResponse<StoreOrder>> =>
        this.request<PaginatedResponse<StoreOrder>>('GET', '/customer/orders', {
          ...options,
          params: params ? transformListParams(params) : undefined,
        }),
    },

    /**
     * Nested resource: Payment Setup Sessions (save payment methods for future use)
     */
    paymentSetupSessions: {
      /**
       * Create a payment setup session
       * Delegates to the payment gateway to initialize a setup flow for saving a payment method
       */
      create: (
        params: CreatePaymentSetupSessionParams,
        options?: RequestOptions
      ): Promise<StorePaymentSetupSession> =>
        this.request<StorePaymentSetupSession>(
          'POST',
          '/customer/payment_setup_sessions',
          { ...options, body: params }
        ),

      /**
       * Get a payment setup session by ID
       */
      get: (id: string, options?: RequestOptions): Promise<StorePaymentSetupSession> =>
        this.request<StorePaymentSetupSession>('GET', `/customer/payment_setup_sessions/${id}`, options),

      /**
       * Complete a payment setup session
       * Confirms the setup with the provider, resulting in a saved payment method
       */
      complete: (
        id: string,
        params?: CompletePaymentSetupSessionParams,
        options?: RequestOptions
      ): Promise<StorePaymentSetupSession> =>
        this.request<StorePaymentSetupSession>(
          'PATCH',
          `/customer/payment_setup_sessions/${id}/complete`,
          { ...options, body: params }
        ),
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
