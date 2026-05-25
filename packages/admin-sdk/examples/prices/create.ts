import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const price = await client.prices.create({
  variant_id: 'variant_xxx',
  currency: 'USD',
  amount: '19.99',
})
// endregion:example

export { price }
