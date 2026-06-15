import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const channel = await client.channels.update('channel_xxx', {
  name: 'Wholesale (Updated)',
  active: false,
})

// endregion:example

export { channel }
