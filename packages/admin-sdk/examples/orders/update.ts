import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const order = await client.orders.update('or_UkLWZg9DAJ', {
  email: 'updated@example.com',
  internal_note: 'VIP — gift wrap on next order',
})
// endregion:example

export { order }
