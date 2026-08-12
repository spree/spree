import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const fulfillment = await client.orders.fulfillments.purchaseLabel(
  'or_UkLWZg9DAJ',
  'ful_UkLWZg9DAJ',
)

// The label is ready to print; the parcel is still unfulfilled.
const label = fulfillment.documents.find((document) => document.kind === 'label')

// endregion:example

export { label }
