import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const orderChange = await client.orders.orderChanges.confirm('or_UkLWZg9DAJ', 'ordchg_UkLWZg9DAJ')

// endregion:example

export { orderChange }
