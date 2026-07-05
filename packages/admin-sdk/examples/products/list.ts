import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: products } = await client.products.list({
  name_cont: 'shirt',
  status_eq: 'active',
  sort: '-created_at',
  limit: 25,
})
// endregion:example

export { products }
