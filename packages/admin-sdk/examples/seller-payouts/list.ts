import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: payouts } = await client.sellerPayouts.list({
  period_end_gteq: '2026-09-01',
  sort: '-created_at',
})

// endregion:example

export { payouts }
