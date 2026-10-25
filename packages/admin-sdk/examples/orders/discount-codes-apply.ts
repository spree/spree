import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const order = await client.orders.discountCodes.create('or_UkLWZg9DAJ', {
  code: 'SUMMER20',
})

// endregion:example

export { order }
