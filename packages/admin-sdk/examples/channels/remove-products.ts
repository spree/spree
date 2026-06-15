import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { product_count } = await client.channels.removeProducts('channel_xxx', {
  product_ids: ['prod_xxx', 'prod_yyy'],
})

// endregion:example

export { product_count }
