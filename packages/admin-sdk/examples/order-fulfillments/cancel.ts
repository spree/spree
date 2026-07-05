import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const fulfillment = await client.orders.fulfillments.cancel('or_UkLWZg9DAJ', 'ful_UkLWZg9DAJ')
// endregion:example

export { fulfillment }
