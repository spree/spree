import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const result = await client.customers.bulkRemoveTags({
  ids: ['cus_UkLWZg9DAJ'],
  tags: ['vip'],
})
// endregion:example

export { result }
