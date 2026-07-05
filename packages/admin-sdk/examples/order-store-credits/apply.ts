import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const order = await client.orders.storeCredits.apply('or_UkLWZg9DAJ', {
  amount: '25.00',
})

// endregion:example

export { order }
