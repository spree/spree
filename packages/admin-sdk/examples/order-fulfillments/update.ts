import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const fulfillment = await client.orders.fulfillments.update('or_UkLWZg9DAJ', 'ful_UkLWZg9DAJ', {
  tracking: '1Z999AA10123456784',
})
// endregion:example

export { fulfillment }
