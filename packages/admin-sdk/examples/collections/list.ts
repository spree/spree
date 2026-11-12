import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: collections } = await client.collections.list({
  name_cont: 'Sale',
  limit: 25,
})

// endregion:example

export { collections }
