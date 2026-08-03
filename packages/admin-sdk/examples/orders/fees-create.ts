import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const fee = await client.orders.fees.create('or_abc123', {
  label: 'Gift wrap',
  amount: 4,
  kind: 'gift_wrap',
})

// endregion:example

export { fee }
