import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Commission already charged is unaffected — the lines keep their own snapshot.
await client.commissionRates.delete('comrt_a1b2c3')

// endregion:example
