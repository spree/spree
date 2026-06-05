import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Re-enable an endpoint that was auto-disabled after repeated delivery failures.
const endpoint = await client.webhookEndpoints.enable('whe_xxx')

// endregion:example

export { endpoint }
