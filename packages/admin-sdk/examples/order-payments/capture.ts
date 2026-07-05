import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const payment = await client.orders.payments.capture('or_UkLWZg9DAJ', 'pay_UkLWZg9DAJ')
// endregion:example

export { payment }
