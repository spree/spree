import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: deliveries } = await client.orders.fulfillments.deliveries.list(
  'or_UkLWZg9DAJ',
  'ful_UkLWZg9DAJ',
)

// Each carries its own carrier status: pending, in_transit, delivered, ...
// endregion:example

export { deliveries }
