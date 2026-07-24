import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const taxLine = await client.orders.taxLines.get('or_UkLWZg9DAJ', 'tl_UkLWZg9DAJ')

// endregion:example

export { taxLine }
