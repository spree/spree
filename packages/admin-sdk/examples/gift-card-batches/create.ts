import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const batch = await client.giftCardBatches.create({
  prefix: 'WELCOME',
  amount: '25.00',
  currency: 'USD',
  codes_count: 100,
  expires_at: '2030-12-31',
})
// endregion:example

export { batch }
