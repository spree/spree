import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { added_count } = await client.collections.products.create('coll_UkLWZg9DAJ', [
  'prod_UkLWZg9DAJ',
  'prod_9XbR2kQwLm',
])

// endregion:example

export { added_count }
