import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const result = await client.products.bulkRemoveTags({
  ids: ['prod_UkLWZg9DAJ', 'prod_9XbR2kQwLm'],
  tags: ['summer'],
})

// endregion:example

export { result }
