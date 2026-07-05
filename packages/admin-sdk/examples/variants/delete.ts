import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
await client.products.variants.delete('prod_86Rf07xd4z', 'variant_k5nR8xLq')
// endregion:example
