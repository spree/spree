import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const exchange = await client.orders.exchanges.approve('or_UkLWZg9DAJ', 'exch_UkLWZg9DAJ')

// endregion:example

export { exchange }
