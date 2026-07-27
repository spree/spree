import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const rule = await client.channels.orderRoutingRules.create('ch_UkLWZg9DAJ', {
  type: 'preferred_location',
})

// endregion:example

export { rule }
