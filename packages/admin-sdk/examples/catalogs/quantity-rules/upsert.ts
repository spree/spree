import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Keyed by product. Both values null clears that product's terms.
await client.catalogs.quantityRules.upsert('cat_UkLWZg9DAJ', {
  terms: {
    prod_86Rf07xd4z: { minimum_order_quantity: 48, order_multiple: 24 },
    prod_9XbR2kQwLm: { minimum_order_quantity: null, order_multiple: null },
  },
})

// endregion:example
