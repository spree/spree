import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const result = await client.products.bulkAddToChannels({
  ids: ['prod_UkLWZg9DAJ', 'prod_9XbR2kQwLm'],
  channel_ids: ['channel_AbC123XyZ'],
})

// endregion:example

export { result }
