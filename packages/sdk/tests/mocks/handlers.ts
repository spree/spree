import { http, HttpResponse } from 'msw';

const BASE_URL = 'https://demo.spreecommerce.org';
const API_PREFIX = `${BASE_URL}/api/v3/store`;

// Reusable fixture data
export const fixtures = {
  product: {
    id: 'prod_1',
    name: 'Test Product',
    description: 'A test product',
    slug: 'test-product',
    price: { amount: '19.99', currency: 'USD', display: '$19.99' },
    purchasable: true,
    in_stock: true,
  },
  cart: {
    id: 'cart_1',
    number: 'R123456',
    state: 'cart',
    total: '0.00',
    item_total: '0.00',
    token: 'guest-order-token',
    checkout_steps: ['address', 'delivery', 'payment', 'confirm'],
    state_lock_version: 0,
    items: [],
    payment_methods: [],
  },
  order: {
    id: 'or_1',
    number: 'R123456',
    email: 'test@example.com',
    total: '0.00',
    item_total: '0.00',
    completed_at: '2026-03-01T00:00:00.000Z',
    shipment_state: 'shipped',
    payment_state: 'paid',
    items: [],
  },
  lineItem: {
    id: 'li_1',
    quantity: 2,
    currency: 'USD',
    price: '19.99',
    variant_id: 'var_1',
  },
  user: {
    id: 'user_1',
    email: 'test@example.com',
    first_name: 'Test',
    last_name: 'User',
    phone: null as string | null,
    accepts_email_marketing: false,
  },
  address: {
    id: 'addr_1',
    firstname: 'Test',
    lastname: 'User',
    address1: '123 Main St',
    city: 'New York',
    zipcode: '10001',
    country_iso: 'US',
    state_abbr: 'NY',
  },
  category: {
    id: 'ctg_1',
    name: 'Clothing',
    permalink: 'clothing/shirts',
    position: 1,
  },
  country: {
    iso: 'US',
    iso3: 'USA',
    name: 'United States',
    states_required: true,
    zipcode_required: true,
  },
  market: {
    id: 'mkt_1',
    name: 'North America',
    currency: 'USD',
    default_locale: 'en',
    supported_locales: ['en', 'es'],
    tax_inclusive: false,
    default: true,
    countries: [
      { iso: 'US', iso3: 'USA', name: 'United States', states_required: true, zipcode_required: true },
    ],
  },
  currency: {
    iso_code: 'USD',
    name: 'United States Dollar',
    symbol: '$',
  },
  locale: {
    code: 'en',
    name: 'English',
  },
  wishlist: {
    id: 'wl_1',
    name: 'My Wishlist',
    is_private: false,
    is_default: true,
  },
  wishedItem: {
    id: 'wi_1',
    quantity: 1,
    variant_id: 'var_1',
  },
};

const paginationMeta = { page: 1, limit: 25, count: 1, pages: 1 };

export const handlers = [
  // Auth
  http.post(`${API_PREFIX}/auth/login`, () =>
    HttpResponse.json({ token: 'test-jwt-token', user: fixtures.user })
  ),

  http.post(`${API_PREFIX}/customers`, () =>
    HttpResponse.json({ token: 'test-jwt-token', user: fixtures.user })
  ),

  http.post(`${API_PREFIX}/auth/refresh`, () =>
    HttpResponse.json({ token: 'refreshed-jwt-token', user: fixtures.user })
  ),

  // Products
  http.get(`${API_PREFIX}/products`, () =>
    HttpResponse.json({ data: [fixtures.product], meta: paginationMeta })
  ),

  http.get(`${API_PREFIX}/products/filters`, () =>
    HttpResponse.json({
      filters: [],
      sort_options: [{ id: 'default', label: 'Default' }],
      default_sort: 'default',
      total_count: 1,
    })
  ),

  http.get(`${API_PREFIX}/products/:id`, () =>
    HttpResponse.json(fixtures.product)
  ),

  // Categories
  http.get(`${API_PREFIX}/categories`, () =>
    HttpResponse.json({ data: [fixtures.category], meta: paginationMeta })
  ),

  http.get(`${API_PREFIX}/categories/:id/products`, () =>
    HttpResponse.json({ data: [fixtures.product], meta: paginationMeta })
  ),

  http.get(`${API_PREFIX}/categories/:id`, () =>
    HttpResponse.json(fixtures.category)
  ),

  // Countries
  http.get(`${API_PREFIX}/countries`, () =>
    HttpResponse.json({ data: [fixtures.country] })
  ),

  http.get(`${API_PREFIX}/countries/:iso`, () =>
    HttpResponse.json(fixtures.country)
  ),

  // Currencies
  http.get(`${API_PREFIX}/currencies`, () =>
    HttpResponse.json({ data: [fixtures.currency] })
  ),

  // Locales
  http.get(`${API_PREFIX}/locales`, () =>
    HttpResponse.json({ data: [fixtures.locale] })
  ),

  // Markets
  http.get(`${API_PREFIX}/markets`, () =>
    HttpResponse.json({ data: [fixtures.market] })
  ),

  http.get(`${API_PREFIX}/markets/resolve`, () =>
    HttpResponse.json(fixtures.market)
  ),

  http.get(`${API_PREFIX}/markets/:id/countries`, () =>
    HttpResponse.json({ data: [fixtures.country] })
  ),

  http.get(`${API_PREFIX}/markets/:id/countries/:iso`, () =>
    HttpResponse.json(fixtures.country)
  ),

  http.get(`${API_PREFIX}/markets/:id`, () =>
    HttpResponse.json(fixtures.market)
  ),

  // Carts
  http.get(`${API_PREFIX}/carts`, () =>
    HttpResponse.json({ data: [fixtures.cart], meta: { page: 1, limit: 25, count: 1, pages: 1, from: 1, to: 1, in: 1, previous: null, next: null } })
  ),

  http.post(`${API_PREFIX}/carts`, () =>
    HttpResponse.json({ ...fixtures.cart, token: 'new-cart-token' })
  ),

  http.get(`${API_PREFIX}/carts/:cartId`, () =>
    HttpResponse.json(fixtures.cart)
  ),

  http.patch(`${API_PREFIX}/carts/:cartId`, () =>
    HttpResponse.json(fixtures.cart)
  ),

  http.delete(`${API_PREFIX}/carts/:cartId`, () =>
    new HttpResponse(null, { status: 204 })
  ),

  http.patch(`${API_PREFIX}/carts/:cartId/associate`, () =>
    HttpResponse.json(fixtures.cart)
  ),

  http.post(`${API_PREFIX}/carts/:cartId/complete`, () =>
    HttpResponse.json(fixtures.order)
  ),

  // Carts > Items
  http.post(`${API_PREFIX}/carts/:cartId/items`, () =>
    HttpResponse.json(fixtures.cart)
  ),

  http.patch(`${API_PREFIX}/carts/:cartId/items/:id`, () =>
    HttpResponse.json(fixtures.cart)
  ),

  http.delete(`${API_PREFIX}/carts/:cartId/items/:id`, () =>
    HttpResponse.json(fixtures.cart)
  ),

  // Carts > Coupon Codes
  http.post(`${API_PREFIX}/carts/:cartId/coupon_codes`, () =>
    HttpResponse.json(fixtures.cart)
  ),

  http.delete(`${API_PREFIX}/carts/:cartId/coupon_codes/:code`, () =>
    HttpResponse.json(fixtures.cart)
  ),

  // Carts > Shipments
  http.get(`${API_PREFIX}/carts/:cartId/shipments`, () =>
    HttpResponse.json({ data: [], meta: { count: 0 } })
  ),

  http.patch(`${API_PREFIX}/carts/:cartId/shipments/:id`, () =>
    HttpResponse.json(fixtures.cart)
  ),

  // Carts > Payment Methods
  http.get(`${API_PREFIX}/carts/:cartId/payment_methods`, () =>
    HttpResponse.json({ data: [], meta: { count: 0 } })
  ),

  // Carts > Payments
  http.get(`${API_PREFIX}/carts/:cartId/payments`, () =>
    HttpResponse.json({
      data: [{
        id: 'py_1',
        payment_method_id: 'pm_1',
        state: 'checkout',
        response_code: null,
        number: 'P1234',
        amount: '19.99',
        display_amount: '$19.99',
        source_type: 'credit_card',
        source_id: 'card_1',
        source: { id: 'card_1', cc_type: 'visa', last_digits: '4242', name: 'Test User', month: '12', year: '2028' },
        created_at: '2026-02-17T00:00:00.000Z',
        updated_at: '2026-02-17T00:00:00.000Z',
        payment_method: { id: 'pm_1', name: 'Credit Card', description: null, type: 'Spree::Gateway::Bogus', session_required: true },
      }],
      meta: { count: 1 },
    })
  ),

  http.get(`${API_PREFIX}/carts/:cartId/payments/:id`, () =>
    HttpResponse.json({
      id: 'py_1',
      payment_method_id: 'pm_1',
      state: 'checkout',
      response_code: null,
      number: 'P1234',
      amount: '19.99',
      display_amount: '$19.99',
      source_type: 'credit_card',
      source_id: 'card_1',
      source: { id: 'card_1', cc_type: 'visa', last_digits: '4242', name: 'Test User', month: '12', year: '2028' },
      created_at: '2026-02-17T00:00:00.000Z',
      updated_at: '2026-02-17T00:00:00.000Z',
      payment_method: { id: 'pm_1', name: 'Credit Card', description: null, type: 'Spree::Gateway::Bogus', session_required: true },
    })
  ),

  http.post(`${API_PREFIX}/carts/:cartId/payments`, () =>
    HttpResponse.json({
      id: 'py_2',
      payment_method_id: 'pm_2',
      state: 'checkout',
      response_code: null,
      number: 'P5678',
      amount: '19.99',
      display_amount: '$19.99',
      source_type: null,
      source_id: null,
      source: null,
      created_at: '2026-02-17T00:00:00.000Z',
      updated_at: '2026-02-17T00:00:00.000Z',
      payment_method: { id: 'pm_2', name: 'Check', description: null, type: 'Spree::PaymentMethod::Check', session_required: false },
    }, { status: 201 })
  ),

  // Carts > Payment Sessions
  http.post(`${API_PREFIX}/carts/:cartId/payment_sessions`, () =>
    HttpResponse.json({
      id: 'ps_1',
      status: 'pending',
      amount: '99.99',
      currency: 'USD',
      external_id: 'bogus_abc123',
      external_data: { client_secret: 'bogus_secret_xyz' },
      expires_at: null,
      customer_external_id: null,
      payment_method_id: 'pm_1',
      order_id: 'order_1',
      created_at: '2026-02-13T00:00:00.000Z',
      updated_at: '2026-02-13T00:00:00.000Z',
      payment_method: { id: 'pm_1', name: 'Credit Card', description: null, type: 'Spree::Gateway::Bogus' },
    }, { status: 201 })
  ),

  http.get(`${API_PREFIX}/carts/:cartId/payment_sessions/:id`, () =>
    HttpResponse.json({
      id: 'ps_1',
      status: 'pending',
      amount: '99.99',
      currency: 'USD',
      external_id: 'bogus_abc123',
      external_data: { client_secret: 'bogus_secret_xyz' },
      expires_at: null,
      customer_external_id: null,
      payment_method_id: 'pm_1',
      order_id: 'order_1',
      created_at: '2026-02-13T00:00:00.000Z',
      updated_at: '2026-02-13T00:00:00.000Z',
      payment_method: { id: 'pm_1', name: 'Credit Card', description: null, type: 'Spree::Gateway::Bogus' },
    })
  ),

  http.patch(`${API_PREFIX}/carts/:cartId/payment_sessions/:id/complete`, () =>
    HttpResponse.json({
      id: 'ps_1',
      status: 'completed',
      amount: '99.99',
      currency: 'USD',
      external_id: 'bogus_abc123',
      external_data: { client_secret: 'bogus_secret_xyz' },
      expires_at: null,
      customer_external_id: null,
      payment_method_id: 'pm_1',
      order_id: 'order_1',
      created_at: '2026-02-13T00:00:00.000Z',
      updated_at: '2026-02-13T00:00:00.000Z',
      payment_method: { id: 'pm_1', name: 'Credit Card', description: null, type: 'Spree::Gateway::Bogus' },
    })
  ),

  http.patch(`${API_PREFIX}/carts/:cartId/payment_sessions/:id`, () =>
    HttpResponse.json({
      id: 'ps_1',
      status: 'pending',
      amount: '50.00',
      currency: 'USD',
      external_id: 'bogus_abc123',
      external_data: { client_secret: 'bogus_secret_xyz' },
      expires_at: null,
      customer_external_id: null,
      payment_method_id: 'pm_1',
      order_id: 'order_1',
      created_at: '2026-02-13T00:00:00.000Z',
      updated_at: '2026-02-13T00:00:00.000Z',
      payment_method: { id: 'pm_1', name: 'Credit Card', description: null, type: 'Spree::Gateway::Bogus' },
    })
  ),

  // Carts > Store Credits
  http.post(`${API_PREFIX}/carts/:cartId/store_credits`, () =>
    HttpResponse.json(fixtures.cart)
  ),

  http.delete(`${API_PREFIX}/carts/:cartId/store_credits`, () =>
    HttpResponse.json(fixtures.cart)
  ),

  // Orders (read-only, single lookup)
  http.get(`${API_PREFIX}/orders/:id`, () =>
    HttpResponse.json(fixtures.order)
  ),

  // Customer
  http.get(`${API_PREFIX}/customer`, () =>
    HttpResponse.json(fixtures.user)
  ),

  http.patch(`${API_PREFIX}/customer`, () =>
    HttpResponse.json({ ...fixtures.user, first_name: 'Updated' })
  ),

  // Customer > Orders
  http.get(`${API_PREFIX}/customer/orders`, () =>
    HttpResponse.json({ data: [fixtures.order], meta: paginationMeta })
  ),

  http.get(`${API_PREFIX}/customer/orders/:id`, () =>
    HttpResponse.json(fixtures.order)
  ),

  // Customer > Addresses
  http.get(`${API_PREFIX}/customer/addresses`, () =>
    HttpResponse.json({ data: [fixtures.address], meta: paginationMeta })
  ),

  http.get(`${API_PREFIX}/customer/addresses/:id`, () =>
    HttpResponse.json(fixtures.address)
  ),

  http.post(`${API_PREFIX}/customer/addresses`, () =>
    HttpResponse.json(fixtures.address)
  ),

  http.patch(`${API_PREFIX}/customer/addresses/:id`, () =>
    HttpResponse.json({ ...fixtures.address, city: 'Updated City' })
  ),

  http.delete(`${API_PREFIX}/customer/addresses/:id`, () =>
    new HttpResponse(null, { status: 204 })
  ),

  // Customer > Credit Cards
  http.get(`${API_PREFIX}/customer/credit_cards`, () =>
    HttpResponse.json({ data: [], meta: paginationMeta })
  ),

  http.get(`${API_PREFIX}/customer/credit_cards/:id`, () =>
    HttpResponse.json({ id: 'cc_1', last_digits: '1234' })
  ),

  http.delete(`${API_PREFIX}/customer/credit_cards/:id`, () =>
    new HttpResponse(null, { status: 204 })
  ),

  // Customer > Gift Cards
  http.get(`${API_PREFIX}/customer/gift_cards`, () =>
    HttpResponse.json({ data: [], meta: paginationMeta })
  ),

  http.get(`${API_PREFIX}/customer/gift_cards/:id`, () =>
    HttpResponse.json({ id: 'gc_1', code: 'GIFT123', balance: '50.00' })
  ),

  // Customer > Payment Setup Sessions
  http.post(`${API_PREFIX}/customer/payment_setup_sessions`, () =>
    HttpResponse.json({
      id: 'pss_1',
      status: 'pending',
      external_id: 'seti_abc123',
      external_client_secret: 'seti_secret_xyz',
      external_data: { client_secret: 'seti_secret_xyz' },
      payment_method_id: 'pm_1',
      payment_source_id: null,
      payment_source_type: null,
      customer_id: 'user_1',
      created_at: '2026-02-18T00:00:00.000Z',
      updated_at: '2026-02-18T00:00:00.000Z',
      payment_method: { id: 'pm_1', name: 'Credit Card', description: null, type: 'Spree::Gateway::Bogus' },
    }, { status: 201 })
  ),

  http.get(`${API_PREFIX}/customer/payment_setup_sessions/:id`, () =>
    HttpResponse.json({
      id: 'pss_1',
      status: 'pending',
      external_id: 'seti_abc123',
      external_client_secret: 'seti_secret_xyz',
      external_data: { client_secret: 'seti_secret_xyz' },
      payment_method_id: 'pm_1',
      payment_source_id: null,
      payment_source_type: null,
      customer_id: 'user_1',
      created_at: '2026-02-18T00:00:00.000Z',
      updated_at: '2026-02-18T00:00:00.000Z',
      payment_method: { id: 'pm_1', name: 'Credit Card', description: null, type: 'Spree::Gateway::Bogus' },
    })
  ),

  http.patch(`${API_PREFIX}/customer/payment_setup_sessions/:id/complete`, () =>
    HttpResponse.json({
      id: 'pss_1',
      status: 'completed',
      external_id: 'seti_abc123',
      external_client_secret: 'seti_secret_xyz',
      external_data: { client_secret: 'seti_secret_xyz' },
      payment_method_id: 'pm_1',
      payment_source_id: 'cc_1',
      payment_source_type: 'Spree::CreditCard',
      customer_id: 'user_1',
      created_at: '2026-02-18T00:00:00.000Z',
      updated_at: '2026-02-18T00:00:00.000Z',
      payment_method: { id: 'pm_1', name: 'Credit Card', description: null, type: 'Spree::Gateway::Bogus' },
    })
  ),

  // Customer > Password Resets
  http.post(`${API_PREFIX}/customer/password_resets`, () =>
    HttpResponse.json(
      { message: 'If an account exists for that email, password reset instructions have been sent.' },
      { status: 202 }
    )
  ),

  http.patch(`${API_PREFIX}/customer/password_resets/:token`, () =>
    HttpResponse.json({ token: 'new-jwt-token', user: fixtures.user })
  ),

  // Wishlists
  http.get(`${API_PREFIX}/wishlists`, () =>
    HttpResponse.json({ data: [fixtures.wishlist], meta: paginationMeta })
  ),

  http.get(`${API_PREFIX}/wishlists/:id`, () =>
    HttpResponse.json(fixtures.wishlist)
  ),

  http.post(`${API_PREFIX}/wishlists`, () =>
    HttpResponse.json(fixtures.wishlist)
  ),

  http.patch(`${API_PREFIX}/wishlists/:id`, () =>
    HttpResponse.json({ ...fixtures.wishlist, name: 'Updated Wishlist' })
  ),

  http.delete(`${API_PREFIX}/wishlists/:id`, () =>
    new HttpResponse(null, { status: 204 })
  ),

  // Wishlist Items
  http.post(`${API_PREFIX}/wishlists/:wishlistId/items`, () =>
    HttpResponse.json(fixtures.wishedItem)
  ),

  http.patch(`${API_PREFIX}/wishlists/:wishlistId/items/:id`, () =>
    HttpResponse.json({ ...fixtures.wishedItem, quantity: 3 })
  ),

  http.delete(`${API_PREFIX}/wishlists/:wishlistId/items/:id`, () =>
    new HttpResponse(null, { status: 204 })
  ),
];
