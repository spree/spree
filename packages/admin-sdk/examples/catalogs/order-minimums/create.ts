import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const orderMinimum = await client.catalogs.orderMinimums.create('cat_UkLWZg9DAJ', {
  currency: 'USD',
  amount: '500.00',
})

// endregion:example

export { orderMinimum }
