import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const fee = await client.orders.fees.update('or_UkLWZg9DAJ', 'fee_UkLWZg9DAJ', {
  label: 'Gift wrap',
  amount: '5.00',
})

// endregion:example

export { fee }
