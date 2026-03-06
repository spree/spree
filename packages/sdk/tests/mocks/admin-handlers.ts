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
};

const paginationMeta = { page: 1, limit: 25, count: 1, pages: 1 };

export const adminHandlers = [
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
];
