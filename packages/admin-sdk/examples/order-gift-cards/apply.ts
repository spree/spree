import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
await client.orders.giftCards.apply('or_UkLWZg9DAJ', {
  code: 'GIFT-XXXX-YYYY',
})
// endregion:example
