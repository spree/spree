import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const discount = await client.orders.discounts.update('or_UkLWZg9DAJ', 'disc_UkLWZg9DAJ', {
  label: 'Customer appeasement',
  amount: '15.00',
})

// endregion:example

export { discount }
