import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const commissionRate = await client.commissionRates.get('comrt_a1b2c3')

// endregion:example

export { commissionRate }
