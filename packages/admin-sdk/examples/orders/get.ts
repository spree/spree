import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const order = await client.orders.get('or_UkLWZg9DAJ', {
  expand: ['items', 'fulfillments', 'payments', 'customer'],
})
// endregion:example

export { order }
