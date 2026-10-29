import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const run = await client.maintenanceTaskRuns.create({
  task_name: 'capture_methods',
  dry_run: true,
})

// endregion:example

export { run }
