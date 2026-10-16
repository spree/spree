import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const result = await client.products.bulkAddToCollections({
  ids: ['prod_UkLWZg9DAJ', 'prod_9XbR2kQwLm'],
  collection_ids: ['coll_AbC123XyZq'],
})

// endregion:example

export { result }
