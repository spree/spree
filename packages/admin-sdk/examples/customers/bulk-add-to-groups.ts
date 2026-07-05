import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const result = await client.customers.bulkAddToGroups({
  ids: ['cus_UkLWZg9DAJ', 'cus_QrLWXg9CAJ'],
  customer_group_ids: ['cg_UkLWZg9DAJ'],
})
// endregion:example

export { result }
