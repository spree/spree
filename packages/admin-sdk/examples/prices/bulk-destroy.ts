import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { price_count } = await client.prices.bulkDestroy({
  ids: ['price_xxx', 'price_yyy'],
})
// endregion:example

export { price_count }
