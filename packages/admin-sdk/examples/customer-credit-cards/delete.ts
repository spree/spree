import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
await client.customers.creditCards.delete('cus_UkLWZg9DAJ', 'cc_UkLWZg9DAJ')
// endregion:example
