import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const result = await client.customers.bulkAddTags({
  ids: ['cus_UkLWZg9DAJ', 'cus_QrLWXg9CAJ'],
  tags: ['vip', 'newsletter'],
})
// endregion:example

export { result }
