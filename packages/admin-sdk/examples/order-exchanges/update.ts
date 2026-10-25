import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const exchange = await client.orders.exchanges.update('or_UkLWZg9DAJ', 'exch_UkLWZg9DAJ', {
  memo: 'Customer prefers the larger size',
})

// endregion:example

export { exchange }
