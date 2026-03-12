import type { RequestFn, RequestOptions } from '@spree/sdk-core';
import { transformListParams, getParams } from '@spree/sdk-core';
import type {
  ListResponse,
  PaginatedResponse,
  ListParams,
  AddressParams,
} from '@spree/sdk-core';
import type {
  AuthTokens,
  LoginCredentials,
  RegisterParams,
  ProductListParams,
  ProductFiltersParams,
  ProductFiltersResponse,
  CategoryListParams,
  OrderListParams,
  CreateCartParams,
  AddLineItemParams,
  UpdateLineItemParams,
  UpdateCheckoutParams,
  CreatePaymentParams,
  CreatePaymentSessionParams,
  UpdatePaymentSessionParams,
  CompletePaymentSessionParams,
  CreatePaymentSetupSessionParams,
  CompletePaymentSetupSessionParams,
  Cart,
  CreditCard,
  GiftCard,
  Product,
  Order,
  Country,
  Currency,
  Locale,
  Market,
  Category,
  Payment,
  PaymentMethod,
  PaymentSession,
  PaymentSetupSession,
  Shipment,
  Wishlist,
  WishedItem,
  Address,
  Customer,
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
     * Refresh access token (requires valid Bearer token)
     */
    refresh: (options: RequestOptions): Promise<AuthTokens> =>
      this.request<AuthTokens>('POST', '/auth/refresh', options),
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
    ): Promise<PaginatedResponse<Product>> =>
      this.request<PaginatedResponse<Product>>('GET', '/products', {
        ...options,
        params: transformListParams({ ...params }),
      }),

    /**
     * Get a product by ID or slug
     */
    get: (
      idOrSlug: string,
      params?: { expand?: string[]; fields?: string[] },
      options?: RequestOptions
    ): Promise<Product> =>
      this.request<Product>('GET', `/products/${idOrSlug}`, {
        ...options,
        params: getParams(params),
      }),

    /**
     * Get available filters for products
     * Returns filter options (price range, availability, option types, categories) with counts
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
  // Categories
  // ============================================

  readonly categories = {
    /**
     * List categories
     */
    list: (
      params?: CategoryListParams,
      options?: RequestOptions
    ): Promise<PaginatedResponse<Category>> =>
      this.request<PaginatedResponse<Category>>('GET', '/categories', {
        ...options,
        params: transformListParams({ ...params }),
      }),

    /**
     * Get a category by ID or permalink
     */
    get: (
      idOrPermalink: string,
      params?: { expand?: string[]; fields?: string[] },
      options?: RequestOptions
    ): Promise<Category> =>
      this.request<Category>('GET', `/categories/${idOrPermalink}`, {
        ...options,
        params: getParams(params),
      }),

    /**
     * Nested resource: Products in a category
     */
    products: {
      /**
       * List products in a category
       * @param categoryId - Category ID (prefix_id) or permalink
       */
      list: (
        categoryId: string,
        params?: ProductListParams,
        options?: RequestOptions
      ): Promise<PaginatedResponse<Product>> =>
        this.request<PaginatedResponse<Product>>(
          'GET',
          `/categories/${categoryId}/products`,
          {
            ...options,
            params: transformListParams({ ...params }),
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
    list: (options?: RequestOptions): Promise<ListResponse<Country>> =>
      this.request<ListResponse<Country>>('GET', '/countries', options),

    /**
     * Get a country by ISO code
     * Use `?expand=states` to expand states for address forms
     * @param iso - ISO 3166-1 alpha-2 code (e.g., "US", "DE")
     */
    get: (
      iso: string,
      params?: { expand?: string[]; fields?: string[] },
      options?: RequestOptions
    ): Promise<Country> =>
      this.request<Country>('GET', `/countries/${iso}`, {
        ...options,
        params: getParams(params),
      }),
  };

  readonly currencies = {
    /**
     * List currencies supported by the store (derived from markets)
     */
    list: (options?: RequestOptions): Promise<ListResponse<Currency>> =>
      this.request<ListResponse<Currency>>('GET', '/currencies', options),
  };

  readonly locales = {
    /**
     * List locales supported by the store (derived from markets)
     */
    list: (options?: RequestOptions): Promise<ListResponse<Locale>> =>
      this.request<ListResponse<Locale>>('GET', '/locales', options),
  };

  // ============================================
  // Markets
  // ============================================

  readonly markets = {
    /**
     * List all markets for the current store
     */
    list: (options?: RequestOptions): Promise<ListResponse<Market>> =>
      this.request<ListResponse<Market>>('GET', '/markets', options),

    /**
     * Get a market by prefixed ID
     * @param id - Market prefixed ID (e.g., "mkt_k5nR8xLq")
     */
    get: (id: string, options?: RequestOptions): Promise<Market> =>
      this.request<Market>('GET', `/markets/${id}`, options),

    /**
     * Resolve which market applies for a given country
     * @param country - ISO 3166-1 alpha-2 code (e.g., "DE", "US")
     */
    resolve: (country: string, options?: RequestOptions): Promise<Market> =>
      this.request<Market>('GET', '/markets/resolve', {
        ...options,
        params: { country },
      }),

    /**
     * Nested resource: Countries in a market
     */
    countries: {
      /**
       * List countries belonging to a market
       * @param marketId - Market prefixed ID
       */
      list: (
        marketId: string,
        options?: RequestOptions
      ): Promise<ListResponse<Country>> =>
        this.request<ListResponse<Country>>(
          'GET',
          `/markets/${marketId}/countries`,
          options
        ),

      /**
       * Get a country by ISO code within a market
       * @param marketId - Market prefixed ID
       * @param iso - Country ISO code (e.g., "DE")
       */
      get: (
        marketId: string,
        iso: string,
        params?: { expand?: string[]; fields?: string[] },
        options?: RequestOptions
      ): Promise<Country> =>
        this.request<Country>(
          'GET',
          `/markets/${marketId}/countries/${iso}`,
          { ...options, params: getParams(params) }
        ),
    },
  };

  // ============================================
  // Carts (list all active carts for authenticated users)
  // ============================================

  readonly carts = {
    /**
     * List all active (incomplete) carts for the authenticated user
     */
    list: (options?: RequestOptions): Promise<ListResponse<Cart>> =>
      this.request<ListResponse<Cart>>('GET', '/carts', options),
  };

  // ============================================
  // Cart (pre-purchase, mutable)
  // ============================================

  readonly cart = {
    /**
     * Get current cart
     * Pass spreeToken for guest checkout, or use JWT for authenticated users
     */
    get: (options?: RequestOptions): Promise<Cart> =>
      this.request<Cart>('GET', '/cart', options),

    /**
     * Create a new cart
     * @param params - Optional cart parameters (e.g., metadata, line_items)
     */
    create: (params?: CreateCartParams, options?: RequestOptions): Promise<Cart> =>
      this.request<Cart>('POST', '/cart', {
        ...options,
        body: params,
      }),

    /**
     * Delete the current cart
     */
    delete: (options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', '/cart', options),

    /**
     * Associate a guest cart with the currently authenticated user
     * Requires both JWT token (for authentication) and spreeToken (to identify the cart)
     * @param options - Must include both `token` (JWT) and `spreeToken` (guest cart token)
     */
    associate: (options: RequestOptions): Promise<Cart> =>
      this.request<Cart>('PATCH', '/cart/associate', options),

    /**
     * Nested resource: Line items
     */
    items: {
      /**
       * Add an item to the cart.
       * Returns the updated cart with recalculated totals.
       */
      create: (
        params: AddLineItemParams,
        options?: RequestOptions
      ): Promise<Cart> =>
        this.request<Cart>('POST', '/cart/items', {
          ...options,
          body: params,
        }),

      /**
       * Update a line item quantity.
       * Returns the updated cart with recalculated totals.
       */
      update: (
        lineItemId: string,
        params: UpdateLineItemParams,
        options?: RequestOptions
      ): Promise<Cart> =>
        this.request<Cart>(
          'PATCH',
          `/cart/items/${lineItemId}`,
          { ...options, body: params }
        ),

      /**
       * Remove a line item from the cart.
       * Returns the updated cart with recalculated totals.
       */
      delete: (
        lineItemId: string,
        options?: RequestOptions
      ): Promise<Cart> =>
        this.request<Cart>(
          'DELETE',
          `/cart/items/${lineItemId}`,
          options
        ),
    },

    /**
     * Nested resource: Coupon codes
     */
    couponCodes: {
      /**
       * Apply a coupon code to the cart
       */
      apply: (
        code: string,
        options?: RequestOptions
      ): Promise<Cart> =>
        this.request<Cart>('POST', '/cart/coupon_codes', {
          ...options,
          body: { code },
        }),

      /**
       * Remove a coupon code from the cart
       * @param code - The coupon code string to remove (e.g., 'SAVE10')
       */
      remove: (
        code: string,
        options?: RequestOptions
      ): Promise<Cart> =>
        this.request<Cart>(
          'DELETE',
          `/cart/coupon_codes/${code}`,
          options
        ),
    },
  };

  // ============================================
  // Checkout (cart → order transition)
  // ============================================

  readonly checkout = {
    /**
     * Update checkout info (email, addresses, special instructions).
     * When addresses change, the order state is reverted to address
     * to ensure shipments are recalculated.
     */
    update: (
      params: UpdateCheckoutParams,
      options?: RequestOptions
    ): Promise<Cart> =>
      this.request<Cart>('PATCH', '/checkout', {
        ...options,
        body: params,
      }),

    /**
     * Complete the checkout and finalize the purchase.
     * Returns an Order (not Cart).
     */
    complete: (options?: RequestOptions): Promise<Order> =>
      this.request<Order>('POST', '/checkout/complete', options),

    /**
     * Nested resource: Shipments
     */
    shipments: {
      /**
       * List shipments with shipping rates for the current cart
       */
      list: (options?: RequestOptions): Promise<ListResponse<Shipment>> =>
        this.request<ListResponse<Shipment>>(
          'GET',
          '/checkout/shipments',
          options
        ),

      /**
       * Select a shipping rate for a specific shipment.
       * Returns the updated cart with recalculated totals.
       */
      update: (
        shipmentId: string,
        params: { selected_shipping_rate_id: string },
        options?: RequestOptions
      ): Promise<Cart> =>
        this.request<Cart>(
          'PATCH',
          `/checkout/shipments/${shipmentId}`,
          { ...options, body: params }
        ),
    },

    /**
     * Nested resource: Payment methods
     */
    paymentMethods: {
      /**
       * List available payment methods for the current cart
       */
      list: (options?: RequestOptions): Promise<ListResponse<PaymentMethod>> =>
        this.request<ListResponse<PaymentMethod>>(
          'GET',
          '/checkout/payment_methods',
          options
        ),
    },

    /**
     * Nested resource: Payments
     */
    payments: {
      /**
       * List payments for the current cart
       */
      list: (options?: RequestOptions): Promise<ListResponse<Payment>> =>
        this.request<ListResponse<Payment>>(
          'GET',
          '/checkout/payments',
          options
        ),

      /**
       * Get a payment by ID
       */
      get: (
        paymentId: string,
        options?: RequestOptions
      ): Promise<Payment> =>
        this.request<Payment>(
          'GET',
          `/checkout/payments/${paymentId}`,
          options
        ),

      /**
       * Create a payment for a non-session payment method (e.g. Check, Cash on Delivery, Bank Transfer).
       * For session-based payment methods (e.g. Stripe, PayPal), use checkout.paymentSessions.create() instead.
       */
      create: (
        params: CreatePaymentParams,
        options?: RequestOptions
      ): Promise<Payment> =>
        this.request<Payment>(
          'POST',
          '/checkout/payments',
          { ...options, body: params }
        ),
    },

    /**
     * Nested resource: Payment sessions
     */
    paymentSessions: {
      /**
       * Create a payment session for the current cart.
       * Delegates to the payment gateway to initialize a provider-specific session.
       */
      create: (
        params: CreatePaymentSessionParams,
        options?: RequestOptions
      ): Promise<PaymentSession> =>
        this.request<PaymentSession>(
          'POST',
          '/checkout/payment_sessions',
          { ...options, body: params }
        ),

      /**
       * Get a payment session by ID
       */
      get: (
        sessionId: string,
        options?: RequestOptions
      ): Promise<PaymentSession> =>
        this.request<PaymentSession>(
          'GET',
          `/checkout/payment_sessions/${sessionId}`,
          options
        ),

      /**
       * Update a payment session.
       * Delegates to the payment gateway to sync changes with the provider.
       */
      update: (
        sessionId: string,
        params: UpdatePaymentSessionParams,
        options?: RequestOptions
      ): Promise<PaymentSession> =>
        this.request<PaymentSession>(
          'PATCH',
          `/checkout/payment_sessions/${sessionId}`,
          { ...options, body: params }
        ),

      /**
       * Complete a payment session.
       * Confirms the payment with the provider, triggering capture/authorization.
       */
      complete: (
        sessionId: string,
        params?: CompletePaymentSessionParams,
        options?: RequestOptions
      ): Promise<PaymentSession> =>
        this.request<PaymentSession>(
          'PATCH',
          `/checkout/payment_sessions/${sessionId}/complete`,
          { ...options, body: params }
        ),
    },

    /**
     * Store credits
     */
    storeCredits: {
      /**
       * Apply store credit to the current cart
       */
      apply: (
        amount?: number,
        options?: RequestOptions
      ): Promise<Cart> =>
        this.request<Cart>('POST', '/checkout/store_credits', {
          ...options,
          body: amount ? { amount } : undefined,
        }),

      /**
       * Remove store credit from the current cart
       */
      remove: (options?: RequestOptions): Promise<Cart> =>
        this.request<Cart>(
          'DELETE',
          '/checkout/store_credits',
          options
        ),
    },
  };

  // ============================================
  // Orders (post-purchase, read-only)
  // ============================================

  readonly orders = {
    /**
     * Get a completed order by prefixed ID.
     * Accessible via JWT (authenticated users) or spreeToken (guests).
     */
    get: (
      id: string,
      params?: { expand?: string[]; fields?: string[] },
      options?: RequestOptions
    ): Promise<Order> =>
      this.request<Order>('GET', `/orders/${id}`, {
        ...options,
        params: getParams(params),
      }),
  };

  // ============================================
  // Customer
  // ============================================

  readonly customers = {
    /**
     * Register a new customer account
     */
    create: (params: RegisterParams): Promise<AuthTokens> =>
      this.request<AuthTokens>('POST', '/customers', { body: params }),
  };

  readonly customer = {
    /**
     * Get current customer profile
     */
    get: (options?: RequestOptions): Promise<Customer> =>
      this.request<Customer>('GET', '/customer', options),

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
        /** Required when changing email or password */
        current_password?: string
        accepts_email_marketing?: boolean
        phone?: string
        /** Arbitrary key-value metadata (stored, not returned in responses) */
        metadata?: Record<string, unknown>
      },
      options?: RequestOptions
    ): Promise<Customer> =>
      this.request<Customer>('PATCH', '/customer', {
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
      ): Promise<PaginatedResponse<Address>> =>
        this.request<PaginatedResponse<Address>>(
          'GET',
          '/customer/addresses',
          { ...options, params: transformListParams({ ...params }) }
        ),

      /**
       * Get an address by ID
       */
      get: (id: string, options?: RequestOptions): Promise<Address> =>
        this.request<Address>('GET', `/customer/addresses/${id}`, options),

      /**
       * Create an address
       */
      create: (
        params: AddressParams,
        options?: RequestOptions
      ): Promise<Address> =>
        this.request<Address>('POST', '/customer/addresses', {
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
      ): Promise<Address> =>
        this.request<Address>('PATCH', `/customer/addresses/${id}`, {
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
      ): Promise<Address> =>
        this.request<Address>('PATCH', `/customer/addresses/${id}/mark_as_default`, {
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
      ): Promise<PaginatedResponse<CreditCard>> =>
        this.request<PaginatedResponse<CreditCard>>(
          'GET',
          '/customer/credit_cards',
          { ...options, params: transformListParams({ ...params }) }
        ),

      /**
       * Get a credit card by ID
       */
      get: (id: string, options?: RequestOptions): Promise<CreditCard> =>
        this.request<CreditCard>('GET', `/customer/credit_cards/${id}`, options),

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
      ): Promise<PaginatedResponse<GiftCard>> =>
        this.request<PaginatedResponse<GiftCard>>(
          'GET',
          '/customer/gift_cards',
          { ...options, params: transformListParams({ ...params }) }
        ),

      /**
       * Get a gift card by ID
       */
      get: (id: string, options?: RequestOptions): Promise<GiftCard> =>
        this.request<GiftCard>('GET', `/customer/gift_cards/${id}`, options),
    },

    /**
     * Nested resource: Orders (customer order history)
     */
    orders: {
      /**
       * List completed orders for the authenticated customer
       */
      list: (
        params?: OrderListParams,
        options?: RequestOptions
      ): Promise<PaginatedResponse<Order>> =>
        this.request<PaginatedResponse<Order>>('GET', '/customer/orders', {
          ...options,
          params: transformListParams({ ...params }),
        }),

      /**
       * Get a completed order by prefixed ID
       */
      get: (
        id: string,
        params?: { expand?: string[]; fields?: string[] },
        options?: RequestOptions
      ): Promise<Order> =>
        this.request<Order>('GET', `/customer/orders/${id}`, {
          ...options,
          params: getParams(params),
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
      ): Promise<PaymentSetupSession> =>
        this.request<PaymentSetupSession>(
          'POST',
          '/customer/payment_setup_sessions',
          { ...options, body: params }
        ),

      /**
       * Get a payment setup session by ID
       */
      get: (id: string, options?: RequestOptions): Promise<PaymentSetupSession> =>
        this.request<PaymentSetupSession>('GET', `/customer/payment_setup_sessions/${id}`, options),

      /**
       * Complete a payment setup session
       * Confirms the setup with the provider, resulting in a saved payment method
       */
      complete: (
        id: string,
        params?: CompletePaymentSetupSessionParams,
        options?: RequestOptions
      ): Promise<PaymentSetupSession> =>
        this.request<PaymentSetupSession>(
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
    ): Promise<PaginatedResponse<Wishlist>> =>
      this.request<PaginatedResponse<Wishlist>>('GET', '/wishlists', {
        ...options,
        params: transformListParams({ ...params }),
      }),

    /**
     * Get a wishlist by ID
     */
    get: (
      id: string,
      params?: { expand?: string[]; fields?: string[] },
      options?: RequestOptions
    ): Promise<Wishlist> =>
      this.request<Wishlist>('GET', `/wishlists/${id}`, {
        ...options,
        params: getParams(params),
      }),

    /**
     * Create a wishlist
     */
    create: (
      params: { name: string; is_private?: boolean; is_default?: boolean },
      options?: RequestOptions
    ): Promise<Wishlist> =>
      this.request<Wishlist>('POST', '/wishlists', {
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
    ): Promise<Wishlist> =>
      this.request<Wishlist>('PATCH', `/wishlists/${id}`, {
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
      ): Promise<WishedItem> =>
        this.request<WishedItem>('POST', `/wishlists/${wishlistId}/items`, {
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
      ): Promise<WishedItem> =>
        this.request<WishedItem>(
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
