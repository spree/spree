import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// With no body, the parcel's carrier account buys the label.
const label = await client.orders.fulfillments.labels.create('or_UkLWZg9DAJ', 'ful_UkLWZg9DAJ')

// The tracking number is now on the parcel's first delivery, and the label is
// ready to print. What the merchant paid the carrier is label.display_cost.
// endregion:example

export { label }
