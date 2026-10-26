import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: runs } = await client.maintenanceTaskRuns.list({ status_eq: 'succeeded' })

// endregion:example

export { runs }
