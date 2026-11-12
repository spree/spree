import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const label = await client.orders.fulfillments.labels.get(
  'or_UkLWZg9DAJ',
  'ful_UkLWZg9DAJ',
  'lbl_UkLWZg9DAJ',
)

// endregion:example

export { label }
