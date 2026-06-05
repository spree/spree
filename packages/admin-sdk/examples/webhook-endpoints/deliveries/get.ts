import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const delivery = await client.webhookEndpoints.deliveries.get('whe_xxx', 'whd_xxx')

// endregion:example

export { delivery }
