import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: customers } = await client.customers.list({
  search: 'jane',
  sort: '-created_at',
  limit: 25,
})
// endregion:example

export { customers }
