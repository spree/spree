import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const orderMinimum = await client.catalogs.orderMinimums.update(
  'cat_UkLWZg9DAJ',
  'com_k5nR8xLqPz',
  { amount: '750.00' },
)

// endregion:example

export { orderMinimum }
