import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Deprecated: use client.orders.fulfillments.labels.create() instead, which
// answers with the label itself. Removed in Spree 6.1.
const fulfillment = await client.orders.fulfillments.purchaseLabel(
  'or_UkLWZg9DAJ',
  'ful_UkLWZg9DAJ',
)

// The label is ready to print; the parcel is still unfulfilled.
const label = fulfillment.labels[0]

// endregion:example

export { label }
