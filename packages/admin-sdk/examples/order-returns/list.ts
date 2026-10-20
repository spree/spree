import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: returns } = await client.orders.returns.list('or_UkLWZg9DAJ')

// endregion:example

export { returns }
