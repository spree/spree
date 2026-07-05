import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const order = await client.orders.complete('or_UkLWZg9DAJ', {
  notify_customer: true,
})
// endregion:example

export { order }
