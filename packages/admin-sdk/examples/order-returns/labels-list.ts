import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: labels } = await client.orders.returns.labels.list('or_UkLWZg9DAJ', 'ret_UkLWZg9DAJ')

// endregion:example

export { labels }
