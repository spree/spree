import { adminClient, setApiClient } from '@spree/dashboard-core'

/**
 * Registers the Admin API client as this panel's client.
 *
 * `@spree/dashboard-core` is shared with the seller panel, which talks to a
 * different API with different credentials, so the framework holds no client
 * of its own — each host installs one. Side-effect import, run before any
 * provider mounts.
 */
setApiClient({
  auth: adminClient.auth,
  setToken: (token: string) => adminClient.setToken(token),
  onUnauthorized: (handler) => adminClient.onUnauthorized(handler),
  clearTenant: () => adminClient.setStore(''),
  fetchPermissions: async () => {
    const response = await adminClient.me.get()

    return { rules: response.permissions, keys: response.permission_keys ?? [] }
  },
  listCountries: () => adminClient.countries.list({ expand: ['states'] }),
  createDirectUpload: (params) => adminClient.directUploads.create(params),
  // Backs the shared CSV import wizard, which both panels render. The
  // operator imports every registered dataset; a seller's client narrows
  // `types` to their own.
  imports: {
    list: (params) => adminClient.imports.list(params),
    get: (id) => adminClient.imports.get(id),
    create: (params) => adminClient.imports.create(params),
    completeMapping: (id, params) => adminClient.imports.completeMapping(id, params),
    retryFailedRows: (id) => adminClient.imports.retryFailedRows(id),
    delete: (id) => adminClient.imports.delete(id),
    rows: { list: (importId, params) => adminClient.imports.rows.list(importId, params) },
    types: ['products', 'customers', 'product_translations'],
    templateUrl: (type) => `/api/v3/admin/imports/template?type=${encodeURIComponent(type)}`,
    exampleUrl: (type) => `/api/v3/admin/imports/example?type=${encodeURIComponent(type)}`,
    downloadUrl: (id) => `/api/v3/admin/imports/${id}/download`,
  },
  // Backs the shared stock-locations page, which both panels render.
  stockLocations: {
    list: (params) => adminClient.stockLocations.list(params),
    get: (id) => adminClient.stockLocations.get(id),
    create: (params) => adminClient.stockLocations.create(params),
    update: (id, params) => adminClient.stockLocations.update(id, params),
    delete: (id) => adminClient.stockLocations.delete(id),
  },
  // Reference data for the shared product form.
  optionTypes: {
    list: (params) => adminClient.optionTypes.list({ ...params, expand: ['option_values'] }),
    create: (params) => adminClient.optionTypes.create(params),
    update: (id, params) => adminClient.optionTypes.update(id, params),
  },
  categories: { list: (params) => adminClient.categories.list(params) },
  collections: { list: (params) => adminClient.collections.list(params) },
  productTypes: {
    list: (params) => adminClient.productTypes.list(params),
    get: (id) => adminClient.productTypes.get(id),
  },
  // Backs the shared export dialog. `type` is widened to a string by the
  // contract, since a seller's allowlist is a different set from the
  // operator's registry — the API validates it either way.
  exports: {
    create: (params) =>
      adminClient.exports.create(params as Parameters<typeof adminClient.exports.create>[0]),
    get: (id) => adminClient.exports.get(id),
  },
  taxCategories: { list: (params) => adminClient.taxCategories.list(params) },
  deliveryProfiles: { list: (params) => adminClient.deliveryProfiles.list(params) },
  packageTypes: { list: (params) => adminClient.packageTypes.list(params) },
  deleteProductMedia: (productId, mediaId) => adminClient.products.media.delete(productId, mediaId),
  mediaLibrary: { list: (params) => adminClient.media.list(params) },
  markets: { list: (params) => adminClient.markets.list(params) },
  tags: {
    list: (params) => adminClient.tags.list(params as { taggable_type: string; q?: string }),
  },
})
