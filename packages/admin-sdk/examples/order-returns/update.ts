import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const orderReturn = await client.orders.returns.update('or_UkLWZg9DAJ', 'ret_UkLWZg9DAJ', {
  stock_location_id: 'sloc_UkLWZg9DAJ',
  memo: 'Send to the returns warehouse',
})

// endregion:example

export { orderReturn }
