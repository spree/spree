import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
await client.orders.giftCards.remove('or_UkLWZg9DAJ', 'gc_UkLWZg9DAJ')
// endregion:example
