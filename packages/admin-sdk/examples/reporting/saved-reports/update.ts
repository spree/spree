import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const savedReport = await client.reporting.savedReports.update('sq_UkLWZg9DAJ', {
  name: 'Sales by channel (monthly)',
  description: 'For the board pack',
})

// endregion:example

export { savedReport }
