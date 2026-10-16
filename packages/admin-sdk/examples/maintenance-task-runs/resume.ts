import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const run = await client.maintenanceTaskRuns.resume('mtr_UkLWZg9DAJ')

// endregion:example

export { run }
