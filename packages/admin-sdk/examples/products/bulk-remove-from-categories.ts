import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const result = await client.products.bulkRemoveFromCategories({
  ids: ['prod_UkLWZg9DAJ', 'prod_9XbR2kQwLm'],
  category_ids: ['cat_AbC123XyZ'],
})

// endregion:example

export { result }
