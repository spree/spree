import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: orders, meta } = await client.orders.list({
  status_eq: 'complete',
  completed_at_gt: '2026-01-01',
  sort: '-completed_at',
  limit: 25,
})
// endregion:example

export { orders, meta }
