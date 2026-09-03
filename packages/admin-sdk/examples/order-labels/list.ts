import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: labels } = await client.orders.fulfillments.labels.list(
  'or_UkLWZg9DAJ',
  'ful_UkLWZg9DAJ',
)

// endregion:example

export { labels }
