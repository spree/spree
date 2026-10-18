import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: products } = await client.collections.products.list('coll_UkLWZg9DAJ', {
  limit: 25,
})

// endregion:example

export { products }
