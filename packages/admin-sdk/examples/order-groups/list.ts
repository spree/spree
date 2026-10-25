import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: orderGroups } = await client.orderGroups.list({
  email_cont: 'jane@example.com',
  sort: '-created_at',
})

// endregion:example

export { orderGroups }
