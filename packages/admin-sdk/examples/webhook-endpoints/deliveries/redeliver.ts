import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Creates a new delivery row with the same payload + event_name and queues
// it. The original row is preserved for audit history.
const delivery = await client.webhookEndpoints.deliveries.redeliver('whe_xxx', 'whd_xxx')

// endregion:example

export { delivery }
