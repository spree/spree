import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const exchange = await client.orders.exchanges.fulfill('or_UkLWZg9DAJ', 'exch_UkLWZg9DAJ', {
  refund_method: 'store_credit',
})

// endregion:example

export { exchange }
