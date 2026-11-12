import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: transfers } = await client.stockTransfers.list({
  open: true,
  sort: '-created_at',
})

// endregion:example

export { transfers }
