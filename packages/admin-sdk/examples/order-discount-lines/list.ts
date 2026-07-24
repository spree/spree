import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: discountLines } = await client.orders.discountLines.list('or_UkLWZg9DAJ')

// endregion:example

export { discountLines }
