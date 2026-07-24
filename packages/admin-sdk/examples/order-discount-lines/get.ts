import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const discountLine = await client.orders.discountLines.get('or_UkLWZg9DAJ', 'dl_UkLWZg9DAJ')

// endregion:example

export { discountLine }
