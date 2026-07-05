import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const item = await client.orders.items.create('or_UkLWZg9DAJ', {
  variant_id: 'variant_k5nR8xLq',
  quantity: 2,
})
// endregion:example

export { item }
