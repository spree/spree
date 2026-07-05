import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const product = await client.products.update('prod_86Rf07xd4z', {
  name: 'Updated Name',
  status: 'active',
  tags: ['eco', 'sale'],
})
// endregion:example

export { product }
