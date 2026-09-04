import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Postage bought elsewhere: upload the file first, then record it with the
// tracking number printed on it.
const label = await client.orders.fulfillments.labels.create('or_UkLWZg9DAJ', 'ful_UkLWZg9DAJ', {
  file: 'signed_blob_id',
  tracking_number: '1Z879E930346834440',
  cost: '6.50',
  currency: 'USD',
})

// endregion:example

export { label }
