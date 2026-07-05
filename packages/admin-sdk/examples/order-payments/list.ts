import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: payments } = await client.orders.payments.list('or_UkLWZg9DAJ')
// endregion:example

export { payments }
