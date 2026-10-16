import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
await client.orders.fulfillments.deliveries.delete(
  'or_UkLWZg9DAJ',
  'ful_UkLWZg9DAJ',
  'dlv_UkLWZg9DAJ',
)

// endregion:example
