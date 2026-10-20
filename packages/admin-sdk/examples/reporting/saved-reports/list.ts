import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: savedReports } = await client.reporting.savedReports.list()

// endregion:example

export { savedReports }
