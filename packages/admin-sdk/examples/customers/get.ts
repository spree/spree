import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const customer = await client.customers.get('cus_UkLWZg9DAJ', {
  expand: ['addresses', 'store_credits'],
})
// endregion:example

export { customer }
