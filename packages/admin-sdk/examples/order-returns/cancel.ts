import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const orderReturn = await client.orders.returns.cancel('or_UkLWZg9DAJ', 'ret_UkLWZg9DAJ', {
  reason: 'Customer decided to keep the item',
})

// endregion:example

export { orderReturn }
