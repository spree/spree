import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const label = await client.orders.fulfillments.labels.refund(
  'or_UkLWZg9DAJ',
  'ful_UkLWZg9DAJ',
  'lbl_UkLWZg9DAJ',
)

// 'refunded' when the carrier settled at once, 'refund_requested' when it
// will answer later.
const outcome = label.status

// endregion:example

export { outcome }
