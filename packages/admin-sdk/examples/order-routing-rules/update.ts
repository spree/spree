import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const rule = await client.channels.orderRoutingRules.update('ch_UkLWZg9DAJ', 'orule_k5nR8xLq', {
  active: false,
  position: 2,
})

// endregion:example

export { rule }
