import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: exchanges } = await client.exchanges.list({
  status_eq: 'received',
  sort: '-created_at',
})

// endregion:example

export { exchanges }
