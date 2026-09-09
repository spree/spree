import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Staff confirming one consignment arrived. The fulfillment follows once
// every one of its consignments has.
const delivery = await client.orders.fulfillments.deliveries.markDelivered(
  'or_UkLWZg9DAJ',
  'ful_UkLWZg9DAJ',
  'dlv_UkLWZg9DAJ',
)

// endregion:example

export { delivery }
