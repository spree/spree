import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const label = await client.orders.returns.labels.refund(
  'or_UkLWZg9DAJ',
  'ret_UkLWZg9DAJ',
  'lbl_UkLWZg9DAJ',
)

// endregion:example

export { label }
