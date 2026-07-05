import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const item = await client.orders.items.get('or_UkLWZg9DAJ', 'li_UkLWZg9DAJ')
// endregion:example

export { item }
