import { http, HttpResponse } from 'msw';

const BASE_URL = 'https://demo.spreecommerce.org';
const API_PREFIX = `${BASE_URL}/api/v3/admin`;

export const adminFixtures = {
  product: {
    id: 'prod_1',
    name: 'Admin Product',
    description: 'An admin product',
    slug: 'admin-product',
    price: '29.99',
    status: 'active',
    cost_price: '10.00',
    sku: 'ADMIN-001',
  },
  variant: {
    id: 'var_1',
    sku: 'VAR-001',
    price: '29.99',
    weight: '1.5',
    track_inventory: true,
  },
  asset: {
    id: 'asset_1',
    alt: 'Product image',
    position: 1,
    type: 'Spree::Image',
  },
  order: {
    id: 'or_1',
    number: 'R100001',
    state: 'cart',
    email: 'admin@example.com',
    total: '0.00',
    item_total: '0.00',
    channel: 'admin',
    considered_risky: false,
    approved_at: null,
    internal_note: null,
  },
  lineItem: {
    id: 'li_1',
    quantity: 2,
    price: '29.99',
    variant_id: 'var_1',
  },
  optionType: {
    id: 'ot_1',
    name: 'color',
    presentation: 'Color',
    position: 1,
    filterable: true,
  },
  taxonomy: {
    id: 'txmy_1',
    name: 'Categories',
    position: 1,
  },
  taxon: {
    id: 'txon_1',
    name: 'Clothing',
    permalink: 'categories/clothing',
    position: 1,
  },
  shipment: {
    id: 'ship_1',
    number: 'H12345',
    state: 'ready',
    tracking: null,
    tracking_url: null,
    cost: '5.00',
    display_cost: '$5.00',
    shipped_at: null,
    created_at: '2026-03-06T12:00:00.000Z',
    updated_at: '2026-03-06T12:00:00.000Z',
    order_id: 'or_1',
    stock_location_id: 'sl_1',
    metadata: null,
  },
  payment: {
    id: 'py_1',
    payment_method_id: 'pm_1',
    state: 'completed',
    response_code: '12345',
    number: 'P100001',
    amount: '29.99',
    display_amount: '$29.99',
    captured_amount: '29.99',
    created_at: '2026-03-06T12:00:00.000Z',
    updated_at: '2026-03-06T12:00:00.000Z',
    order_id: 'or_1',
    metadata: null,
  },
  refund: {
    id: 're_1',
    transaction_id: 'txn_123',
    created_at: '2026-03-06T12:00:00.000Z',
    updated_at: '2026-03-06T12:00:00.000Z',
    amount: '5.0',
    payment_id: 'py_1',
    refund_reason_id: 'rr_1',
    reimbursement_id: null,
    metadata: null,
  },
  adjustment: {
    id: 'adj_1',
    amount: '-5.0',
    label: 'Admin discount',
    eligible: true,
    state: 'open',
    source_type: null,
    source_id: null,
    adjustable_type: 'Spree::Order',
    adjustable_id: 'or_1',
    order_id: 'or_1',
    included: false,
    created_at: '2026-03-06T12:00:00.000Z',
    updated_at: '2026-03-06T12:00:00.000Z',
  },
};

const paginationMeta = { page: 1, limit: 25, count: 1, pages: 1 };

export const adminFixtureAuth = {
  adminUser: {
    id: 'adm_1',
    email: 'admin@example.com',
    first_name: 'Admin',
    last_name: 'User',
    created_at: '2026-01-01T00:00:00.000Z',
    updated_at: '2026-03-06T12:00:00.000Z',
  },
};

export const adminHandlers = [
  // ============================================
  // Authentication
  // ============================================
  http.post(`${API_PREFIX}/auth/login`, () =>
    HttpResponse.json({ token: 'admin-jwt-token', user: adminFixtureAuth.adminUser })
  ),

  http.post(`${API_PREFIX}/auth/refresh`, () =>
    HttpResponse.json({ token: 'refreshed-admin-jwt-token', user: adminFixtureAuth.adminUser })
  ),

  // ============================================
  // Option Types
  // ============================================
  http.get(`${API_PREFIX}/option_types`, () =>
    HttpResponse.json({ data: [adminFixtures.optionType], meta: paginationMeta })
  ),

  http.post(`${API_PREFIX}/option_types`, () =>
    HttpResponse.json(adminFixtures.optionType, { status: 201 })
  ),

  http.get(`${API_PREFIX}/option_types/:id`, () =>
    HttpResponse.json(adminFixtures.optionType)
  ),

  http.patch(`${API_PREFIX}/option_types/:id`, () =>
    HttpResponse.json({ ...adminFixtures.optionType, presentation: 'Updated Color' })
  ),

  http.delete(`${API_PREFIX}/option_types/:id`, () =>
    new HttpResponse(null, { status: 204 })
  ),

  // ============================================
  // Orders
  // ============================================
  http.get(`${API_PREFIX}/orders`, () =>
    HttpResponse.json({ data: [adminFixtures.order], meta: paginationMeta })
  ),

  http.post(`${API_PREFIX}/orders`, () =>
    HttpResponse.json({ ...adminFixtures.order, email: 'new-order@example.com' }, { status: 201 })
  ),

  http.get(`${API_PREFIX}/orders/:id`, () =>
    HttpResponse.json(adminFixtures.order)
  ),

  http.patch(`${API_PREFIX}/orders/:id/cancel`, () =>
    HttpResponse.json({ ...adminFixtures.order, state: 'canceled' })
  ),

  http.patch(`${API_PREFIX}/orders/:id/approve`, () =>
    HttpResponse.json({ ...adminFixtures.order, approved_at: '2026-03-06T12:00:00.000Z' })
  ),

  http.patch(`${API_PREFIX}/orders/:id/resume`, () =>
    HttpResponse.json({ ...adminFixtures.order, state: 'resumed' })
  ),

  http.post(`${API_PREFIX}/orders/:id/resend_confirmation`, () =>
    HttpResponse.json(adminFixtures.order)
  ),

  http.patch(`${API_PREFIX}/orders/:id`, () =>
    HttpResponse.json({ ...adminFixtures.order, email: 'updated@example.com' })
  ),

  http.delete(`${API_PREFIX}/orders/:id`, () =>
    new HttpResponse(null, { status: 204 })
  ),

  // ============================================
  // Order Line Items
  // ============================================
  http.get(`${API_PREFIX}/orders/:orderId/line_items`, () =>
    HttpResponse.json({ data: [adminFixtures.lineItem], meta: paginationMeta })
  ),

  http.post(`${API_PREFIX}/orders/:orderId/line_items`, () =>
    HttpResponse.json(adminFixtures.lineItem, { status: 201 })
  ),

  http.get(`${API_PREFIX}/orders/:orderId/line_items/:id`, () =>
    HttpResponse.json(adminFixtures.lineItem)
  ),

  http.patch(`${API_PREFIX}/orders/:orderId/line_items/:id`, () =>
    HttpResponse.json({ ...adminFixtures.lineItem, quantity: 5 })
  ),

  http.delete(`${API_PREFIX}/orders/:orderId/line_items/:id`, () =>
    new HttpResponse(null, { status: 204 })
  ),

  // ============================================
  // Products
  // ============================================
  http.get(`${API_PREFIX}/products`, () =>
    HttpResponse.json({ data: [adminFixtures.product], meta: paginationMeta })
  ),

  http.post(`${API_PREFIX}/products`, () =>
    HttpResponse.json(adminFixtures.product, { status: 201 })
  ),

  http.get(`${API_PREFIX}/products/:id`, () =>
    HttpResponse.json(adminFixtures.product)
  ),

  http.patch(`${API_PREFIX}/products/:id`, () =>
    HttpResponse.json({ ...adminFixtures.product, name: 'Updated Product' })
  ),

  http.delete(`${API_PREFIX}/products/:id`, () =>
    new HttpResponse(null, { status: 204 })
  ),

  // ============================================
  // Product Assets
  // ============================================
  http.get(`${API_PREFIX}/products/:productId/assets`, () =>
    HttpResponse.json({ data: [adminFixtures.asset], meta: paginationMeta })
  ),

  http.post(`${API_PREFIX}/products/:productId/assets`, () =>
    HttpResponse.json(adminFixtures.asset, { status: 201 })
  ),

  http.patch(`${API_PREFIX}/products/:productId/assets/:id`, () =>
    HttpResponse.json({ ...adminFixtures.asset, alt: 'Updated alt' })
  ),

  http.delete(`${API_PREFIX}/products/:productId/assets/:id`, () =>
    new HttpResponse(null, { status: 204 })
  ),

  // ============================================
  // Product Variants
  // ============================================
  http.get(`${API_PREFIX}/products/:productId/variants`, () =>
    HttpResponse.json({ data: [adminFixtures.variant], meta: paginationMeta })
  ),

  http.post(`${API_PREFIX}/products/:productId/variants`, () =>
    HttpResponse.json(adminFixtures.variant, { status: 201 })
  ),

  http.get(`${API_PREFIX}/products/:productId/variants/:id`, () =>
    HttpResponse.json(adminFixtures.variant)
  ),

  http.patch(`${API_PREFIX}/products/:productId/variants/:id`, () =>
    HttpResponse.json({ ...adminFixtures.variant, sku: 'VAR-UPDATED' })
  ),

  http.delete(`${API_PREFIX}/products/:productId/variants/:id`, () =>
    new HttpResponse(null, { status: 204 })
  ),

  // ============================================
  // Taxonomies
  // ============================================
  http.get(`${API_PREFIX}/taxonomies`, () =>
    HttpResponse.json({ data: [adminFixtures.taxonomy], meta: paginationMeta })
  ),

  http.post(`${API_PREFIX}/taxonomies`, () =>
    HttpResponse.json(adminFixtures.taxonomy, { status: 201 })
  ),

  http.get(`${API_PREFIX}/taxonomies/:id`, () =>
    HttpResponse.json(adminFixtures.taxonomy)
  ),

  http.patch(`${API_PREFIX}/taxonomies/:id`, () =>
    HttpResponse.json({ ...adminFixtures.taxonomy, name: 'Updated Categories' })
  ),

  http.delete(`${API_PREFIX}/taxonomies/:id`, () =>
    new HttpResponse(null, { status: 204 })
  ),

  // ============================================
  // Taxonomy Taxons
  // ============================================
  http.get(`${API_PREFIX}/taxonomies/:taxonomyId/taxons`, () =>
    HttpResponse.json({ data: [adminFixtures.taxon], meta: paginationMeta })
  ),

  http.post(`${API_PREFIX}/taxonomies/:taxonomyId/taxons`, () =>
    HttpResponse.json(adminFixtures.taxon, { status: 201 })
  ),

  http.get(`${API_PREFIX}/taxonomies/:taxonomyId/taxons/:id`, () =>
    HttpResponse.json(adminFixtures.taxon)
  ),

  http.patch(`${API_PREFIX}/taxonomies/:taxonomyId/taxons/:id`, () =>
    HttpResponse.json({ ...adminFixtures.taxon, name: 'Updated Clothing' })
  ),

  http.delete(`${API_PREFIX}/taxonomies/:taxonomyId/taxons/:id`, () =>
    new HttpResponse(null, { status: 204 })
  ),

  // ============================================
  // Taxons (flat)
  // ============================================
  http.get(`${API_PREFIX}/taxons`, () =>
    HttpResponse.json({ data: [adminFixtures.taxon], meta: paginationMeta })
  ),

  http.get(`${API_PREFIX}/taxons/:id`, () =>
    HttpResponse.json(adminFixtures.taxon)
  ),

  // ============================================
  // Order Shipments
  // ============================================
  http.get(`${API_PREFIX}/orders/:orderId/shipments`, () =>
    HttpResponse.json({ data: [adminFixtures.shipment], meta: paginationMeta })
  ),

  http.get(`${API_PREFIX}/orders/:orderId/shipments/:id`, () =>
    HttpResponse.json(adminFixtures.shipment)
  ),

  http.patch(`${API_PREFIX}/orders/:orderId/shipments/:id/ship`, () =>
    HttpResponse.json({ ...adminFixtures.shipment, state: 'shipped', shipped_at: '2026-03-06T14:00:00.000Z' })
  ),

  http.patch(`${API_PREFIX}/orders/:orderId/shipments/:id/cancel`, () =>
    HttpResponse.json({ ...adminFixtures.shipment, state: 'canceled' })
  ),

  http.patch(`${API_PREFIX}/orders/:orderId/shipments/:id/resume`, () =>
    HttpResponse.json({ ...adminFixtures.shipment, state: 'ready' })
  ),

  http.patch(`${API_PREFIX}/orders/:orderId/shipments/:id/split`, () =>
    HttpResponse.json({ data: [
      { ...adminFixtures.shipment, id: 'ship_1' },
      { ...adminFixtures.shipment, id: 'ship_2', stock_location_id: 'sl_2' },
    ] })
  ),

  http.patch(`${API_PREFIX}/orders/:orderId/shipments/:id`, () =>
    HttpResponse.json({ ...adminFixtures.shipment, tracking: '1Z999AA10123456784' })
  ),

  // ============================================
  // Order Payments
  // ============================================
  http.get(`${API_PREFIX}/orders/:orderId/payments`, () =>
    HttpResponse.json({ data: [adminFixtures.payment], meta: paginationMeta })
  ),

  http.post(`${API_PREFIX}/orders/:orderId/payments`, () =>
    HttpResponse.json(adminFixtures.payment, { status: 201 })
  ),

  http.get(`${API_PREFIX}/orders/:orderId/payments/:id`, () =>
    HttpResponse.json(adminFixtures.payment)
  ),

  http.patch(`${API_PREFIX}/orders/:orderId/payments/:id/capture`, () =>
    HttpResponse.json({ ...adminFixtures.payment, state: 'completed' })
  ),

  http.patch(`${API_PREFIX}/orders/:orderId/payments/:id/void`, () =>
    HttpResponse.json({ ...adminFixtures.payment, state: 'void' })
  ),

  // ============================================
  // Order Refunds
  // ============================================
  http.get(`${API_PREFIX}/orders/:orderId/refunds`, () =>
    HttpResponse.json({ data: [adminFixtures.refund], meta: paginationMeta })
  ),

  http.post(`${API_PREFIX}/orders/:orderId/refunds`, () =>
    HttpResponse.json(adminFixtures.refund, { status: 201 })
  ),

  // ============================================
  // Order Adjustments
  // ============================================
  http.get(`${API_PREFIX}/orders/:orderId/adjustments`, () =>
    HttpResponse.json({ data: [adminFixtures.adjustment], meta: paginationMeta })
  ),

  http.post(`${API_PREFIX}/orders/:orderId/adjustments`, () =>
    HttpResponse.json(adminFixtures.adjustment, { status: 201 })
  ),

  http.get(`${API_PREFIX}/orders/:orderId/adjustments/:id`, () =>
    HttpResponse.json(adminFixtures.adjustment)
  ),

  http.patch(`${API_PREFIX}/orders/:orderId/adjustments/:id`, () =>
    HttpResponse.json({ ...adminFixtures.adjustment, amount: '10.0', label: 'Updated discount' })
  ),

  http.delete(`${API_PREFIX}/orders/:orderId/adjustments/:id`, () =>
    new HttpResponse(null, { status: 204 })
  ),
];
