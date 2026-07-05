import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Fires a synthetic `webhook.test` delivery so you can verify the endpoint is
// reachable and your signature-verification code accepts Spree's payloads.
const delivery = await client.webhookEndpoints.sendTest('whe_xxx')

// endregion:example

export { delivery }
