import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const fulfillment = await client.orders.fulfillments.markDelivered(
  'or_UkLWZg9DAJ',
  'ful_UkLWZg9DAJ',
  { delivered_at: '2026-08-11T09:30:00Z' },
)

// endregion:example

export { fulfillment }
