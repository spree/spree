import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const savedReport = await client.reporting.savedReports.create({
  name: 'Orders by channel',
  description: 'Weekly review',
  query: { metrics: ['total_sales', 'orders'], dimensions: ['channel'] },
})

// endregion:example

export { savedReport }
