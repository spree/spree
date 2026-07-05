import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const refund = await client.orders.refunds.create('or_UkLWZg9DAJ', {
  payment_id: 'pay_UkLWZg9DAJ',
  amount: '5.00',
  refund_reason_id: 'refrsn_UkLWZg9DAJ',
})

// endregion:example

export { refund }
