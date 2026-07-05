import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const price = await client.prices.update('price_xxx', {
  amount: '12.34',
})
// endregion:example

export { price }
