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
  taxCategories: { list: (params) => adminClient.taxCategories.list(params) },
  deliveryProfiles: { list: (params) => adminClient.deliveryProfiles.list(params) },
  deleteProductMedia: (productId, mediaId) => adminClient.products.media.delete(productId, mediaId),
  mediaLibrary: { list: (params) => adminClient.media.list(params) },
  markets: { list: (params) => adminClient.markets.list(params) },
  tags: {
    list: (params) => adminClient.tags.list(params as { taggable_type: string; q?: string }),
  },
})
