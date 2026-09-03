import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
await client.refundReasons.delete('rr_UkLWZg9DAJ')
// endregion:example
