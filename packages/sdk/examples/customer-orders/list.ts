import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const orders = await client.customer.orders.list(
  {
    completed_at_gt: '2026-01-01',
    sort: '-completed_at',
  },
  { token: '<token>' },
)
// endregion:example

export { orders }
