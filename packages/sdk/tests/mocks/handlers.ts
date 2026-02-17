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
  order: {
    id: 'order_1',
    number: 'R123456',
    state: 'cart',
    total: '0.00',
    item_total: '0.00',
    token: 'guest-order-token',
    line_items: [],
  },
  lineItem: {
    id: 'li_1',
    quantity: 2,
    price: '19.99',
    variant_id: 'var_1',
  },
  user: {
    id: 'user_1',
    email: 'test@example.com',
    first_name: 'Test',
    last_name: 'User',
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
  store: {
    id: 'store_1',
    name: 'Test Store',
    url: 'https://demo.spreecommerce.org',
    default_currency: 'USD',
    default_locale: 'en',
  },
  taxonomy: {
    id: 'tax_1',
    name: 'Categories',
    position: 1,
  },
  taxon: {
    id: 'taxon_1',
    name: 'Clothing',
    permalink: 'categories/clothing',
    position: 1,
  },
  country: {
    id: 'country_1',
    iso: 'US',
    name: 'United States',
    states: [],
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

  http.post(`${API_PREFIX}/auth/register`, () =>
    HttpResponse.json({ token: 'test-jwt-token', user: fixtures.user })
  ),

  http.post(`${API_PREFIX}/auth/refresh`, () =>
    HttpResponse.json({ token: 'refreshed-jwt-token', user: fixtures.user })
  ),

  // Store
  http.get(`${API_PREFIX}/store`, () =>
    HttpResponse.json(fixtures.store)
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

  // Taxonomies
  http.get(`${API_PREFIX}/taxonomies`, () =>
    HttpResponse.json({ data: [fixtures.taxonomy], meta: paginationMeta })
  ),

  http.get(`${API_PREFIX}/taxonomies/:id`, () =>
    HttpResponse.json(fixtures.taxonomy)
  ),

  // Taxons
  http.get(`${API_PREFIX}/taxons`, () =>
    HttpResponse.json({ data: [fixtures.taxon], meta: paginationMeta })
  ),

  http.get(`${API_PREFIX}/taxons/:id/products`, () =>
    HttpResponse.json({ data: [fixtures.product], meta: paginationMeta })
  ),

  http.get(`${API_PREFIX}/taxons/:id`, () =>
    HttpResponse.json(fixtures.taxon)
  ),

  // Countries
  http.get(`${API_PREFIX}/countries`, () =>
    HttpResponse.json({ data: [fixtures.country] })
  ),

  http.get(`${API_PREFIX}/countries/:iso`, () =>
    HttpResponse.json(fixtures.country)
  ),

  // Cart
  http.get(`${API_PREFIX}/cart`, () =>
    HttpResponse.json({ ...fixtures.order, token: 'guest-order-token' })
  ),

  http.patch(`${API_PREFIX}/cart/associate`, () =>
    HttpResponse.json({ ...fixtures.order, token: 'guest-order-token' })
  ),

  // Orders
  http.get(`${API_PREFIX}/orders`, () =>
    HttpResponse.json({ data: [fixtures.order], meta: paginationMeta })
  ),

  http.post(`${API_PREFIX}/orders`, () =>
    HttpResponse.json({ ...fixtures.order, order_token: 'new-order-token' })
  ),

  http.get(`${API_PREFIX}/orders/:id`, () =>
    HttpResponse.json(fixtures.order)
  ),

  http.patch(`${API_PREFIX}/orders/:id`, () =>
    HttpResponse.json(fixtures.order)
  ),

  http.patch(`${API_PREFIX}/orders/:id/next`, () =>
    HttpResponse.json({ ...fixtures.order, state: 'address' })
  ),

  http.patch(`${API_PREFIX}/orders/:id/advance`, () =>
    HttpResponse.json({ ...fixtures.order, state: 'complete' })
  ),

  http.patch(`${API_PREFIX}/orders/:id/complete`, () =>
    HttpResponse.json({ ...fixtures.order, state: 'complete' })
  ),

  // Line Items
  http.post(`${API_PREFIX}/orders/:orderId/line_items`, () =>
    HttpResponse.json(fixtures.lineItem)
  ),

  http.patch(`${API_PREFIX}/orders/:orderId/line_items/:id`, () =>
    HttpResponse.json({ ...fixtures.lineItem, quantity: 5 })
  ),

  http.delete(`${API_PREFIX}/orders/:orderId/line_items/:id`, () =>
    new HttpResponse(null, { status: 204 })
  ),

  // Payments
  http.get(`${API_PREFIX}/orders/:orderId/payments`, () =>
    HttpResponse.json({
      data: [
        {
          id: 'py_1',
          payment_method_id: 'pm_1',
          state: 'checkout',
          response_code: '12345',
          number: 'P1234',
          amount: '19.99',
          display_amount: '$19.99',
          source_type: 'credit_card',
          source_id: 'card_1',
          source: {
            id: 'card_1',
            cc_type: 'visa',
            last_digits: '4242',
            month: 12,
            year: 2028,
            name: 'John Doe',
            default: true,
            gateway_payment_profile_id: 'pm_stripe_123',
          },
          created_at: '2026-02-17T00:00:00.000Z',
          updated_at: '2026-02-17T00:00:00.000Z',
          payment_method: { id: 'pm_1', name: 'Credit Card', description: null, type: 'Spree::Gateway::Bogus', session_required: false },
        },
      ],
      meta: paginationMeta,
    })
  ),

  http.get(`${API_PREFIX}/orders/:orderId/payments/:id`, () =>
    HttpResponse.json({
      id: 'py_1',
      payment_method_id: 'pm_1',
      state: 'checkout',
      response_code: '12345',
      number: 'P1234',
      amount: '19.99',
      display_amount: '$19.99',
      source_type: 'credit_card',
      source_id: 'card_1',
      source: {
        id: 'card_1',
        cc_type: 'visa',
        last_digits: '4242',
        month: 12,
        year: 2028,
        name: 'John Doe',
        default: true,
        gateway_payment_profile_id: 'pm_stripe_123',
      },
      created_at: '2026-02-17T00:00:00.000Z',
      updated_at: '2026-02-17T00:00:00.000Z',
      payment_method: { id: 'pm_1', name: 'Credit Card', description: null, type: 'Spree::Gateway::Bogus', session_required: false },
    })
  ),

  // Payment Methods
  http.get(`${API_PREFIX}/orders/:orderId/payment_methods`, () =>
    HttpResponse.json({ data: [], meta: paginationMeta })
  ),

  // Payment Sessions
  http.post(`${API_PREFIX}/orders/:orderId/payment_sessions`, () =>
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

  http.get(`${API_PREFIX}/orders/:orderId/payment_sessions/:id`, () =>
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

  http.patch(`${API_PREFIX}/orders/:orderId/payment_sessions/:id/complete`, () =>
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

  http.patch(`${API_PREFIX}/orders/:orderId/payment_sessions/:id`, () =>
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

  // Coupon Codes
  http.post(`${API_PREFIX}/orders/:orderId/coupon_codes`, () =>
    HttpResponse.json(fixtures.order)
  ),

  http.delete(`${API_PREFIX}/orders/:orderId/coupon_codes/:id`, () =>
    HttpResponse.json(fixtures.order)
  ),

  // Shipments
  http.get(`${API_PREFIX}/orders/:orderId/shipments`, () =>
    HttpResponse.json({ data: [] })
  ),

  http.patch(`${API_PREFIX}/orders/:orderId/shipments/:id`, () =>
    HttpResponse.json({ id: 'ship_1', selected_shipping_rate_id: 'rate_1' })
  ),

  // Store Credits
  http.post(`${API_PREFIX}/orders/:orderId/store_credits`, () =>
    HttpResponse.json(fixtures.order)
  ),

  http.delete(`${API_PREFIX}/orders/:orderId/store_credits`, () =>
    HttpResponse.json(fixtures.order)
  ),

  // Customer
  http.get(`${API_PREFIX}/customer`, () =>
    HttpResponse.json(fixtures.user)
  ),

  http.patch(`${API_PREFIX}/customer`, () =>
    HttpResponse.json({ ...fixtures.user, first_name: 'Updated' })
  ),

  // Customer Addresses
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

  // Customer Credit Cards
  http.get(`${API_PREFIX}/customer/credit_cards`, () =>
    HttpResponse.json({ data: [], meta: paginationMeta })
  ),

  http.get(`${API_PREFIX}/customer/credit_cards/:id`, () =>
    HttpResponse.json({ id: 'cc_1', last_digits: '1234' })
  ),

  http.delete(`${API_PREFIX}/customer/credit_cards/:id`, () =>
    new HttpResponse(null, { status: 204 })
  ),

  // Customer Gift Cards
  http.get(`${API_PREFIX}/customer/gift_cards`, () =>
    HttpResponse.json({ data: [], meta: paginationMeta })
  ),

  http.get(`${API_PREFIX}/customer/gift_cards/:id`, () =>
    HttpResponse.json({ id: 'gc_1', code: 'GIFT123', balance: '50.00' })
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
