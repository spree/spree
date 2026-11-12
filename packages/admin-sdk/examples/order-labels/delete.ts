import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Only a label recorded from an uploaded file can be deleted; refund a bought one.
await client.orders.fulfillments.labels.delete('or_UkLWZg9DAJ', 'ful_UkLWZg9DAJ', 'lbl_UkLWZg9DAJ')

// endregion:example
