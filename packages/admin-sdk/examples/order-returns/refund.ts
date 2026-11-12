import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const orderReturn = await client.orders.returns.refund('or_UkLWZg9DAJ', 'ret_UkLWZg9DAJ', {
  amount: '29.99',
  refund_method: 'original_payment',
})

// endregion:example

export { orderReturn }
