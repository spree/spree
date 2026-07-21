import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
await client.channels.orderRoutingRules.delete('ch_UkLWZg9DAJ', 'orule_k5nR8xLq')
// endregion:example
