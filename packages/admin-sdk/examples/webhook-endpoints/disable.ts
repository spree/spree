import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Pause an endpoint without deleting it. The optional `reason` is shown next
// to the disabled indicator in the admin.
const endpoint = await client.webhookEndpoints.disable('whe_xxx', {
  reason: 'Investigating elevated 5xx rate',
})

// endregion:example

export { endpoint }
