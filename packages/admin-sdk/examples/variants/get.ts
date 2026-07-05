import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const variant = await client.products.variants.get('prod_86Rf07xd4z', 'variant_k5nR8xLq', {
  expand: ['prices', 'stock_items'],
})
// endregion:example

export { variant }
