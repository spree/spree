import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const payment = await client.orders.payments.create('or_UkLWZg9DAJ', {
  payment_method_id: 'pm_UkLWZg9DAJ',
  amount: '99.99',
  source_id: 'cc_UkLWZg9DAJ',
})

// endregion:example

export { payment }
