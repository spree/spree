import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const variant = await client.products.variants.update('prod_86Rf07xd4z', 'variant_k5nR8xLq', {
  sku: 'UPDATED-SKU',
  stock_items: [
    { stock_location_id: 'sloc_UkLWZg9DAJ', count_on_hand: 75 },
  ],
})
// endregion:example

export { variant }
