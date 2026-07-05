import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const customer = await client.customers.update('cus_UkLWZg9DAJ', {
  first_name: 'Updated',
  tags: ['wholesale', 'vip'],
})
// endregion:example

export { customer }
