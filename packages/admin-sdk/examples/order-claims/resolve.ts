import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const claim = await client.orders.claims.resolve('or_UkLWZg9DAJ', 'claim_UkLWZg9DAJ', {
  resolution: 'refund_and_replacement',
  refund_method: 'original_payment',
  amount: '5.00',
})

// endregion:example

export { claim }
