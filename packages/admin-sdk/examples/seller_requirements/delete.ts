import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Stops asking for this, and deletes what sellers submitted against it. To
// keep the record while pausing the ask, update it with `active: false`.
await client.sellerRequirements.delete('selreq_a1b2c3')

// endregion:example
