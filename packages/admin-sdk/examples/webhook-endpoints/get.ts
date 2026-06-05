import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const endpoint = await client.webhookEndpoints.get('whe_xxx')

// endregion:example

export { endpoint }
