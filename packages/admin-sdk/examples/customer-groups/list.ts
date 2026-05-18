import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: groups } = await client.customerGroups.list({ page: 1, limit: 25 })
// endregion:example

export { groups }
