import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const result = await client.reporting.query({
  metrics: ['total_sales', 'orders'],
  dimensions: [{ name: 'completed_at', grain: 'day' }],
  time_range: { preset: 'last_7_days' },
  compare: 'previous_period',
})

// endregion:example

export { result }
