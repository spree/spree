import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const group = await client.customerGroups.create({
  name: 'VIP customers',
  description: 'Top spenders, eligible for early access',
  customer_ids: ['cus_UkLWZg9DAJ', 'cus_QrLWXg9CAJ'],
})
// endregion:example

export { group }
