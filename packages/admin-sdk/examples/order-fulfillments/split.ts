import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: fulfillments } = await client.orders.fulfillments.split(
  'or_UkLWZg9DAJ',
  'ful_UkLWZg9DAJ',
  {
    variant_id: 'var_UkLWZg9DAJ',
    quantity: 1,
  },
)
// endregion:example

export { fulfillments }
