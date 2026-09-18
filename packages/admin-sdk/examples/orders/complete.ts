import { createAdminClient, isOrderGroup } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const result = await client.orders.complete('or_UkLWZg9DAJ', {
  notify_customer: true,
})

// An order holding several sellers' goods becomes one order per seller.
const orders = isOrderGroup(result) ? result.orders : [result]

// endregion:example

export { orders }
