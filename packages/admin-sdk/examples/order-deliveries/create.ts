import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// A second box, or a freight consignment: the carrier is free text, so a
// forwarder's PRO number is as valid as a parcel number.
const delivery = await client.orders.fulfillments.deliveries.create(
  'or_UkLWZg9DAJ',
  'ful_UkLWZg9DAJ',
  { tracking_number: 'PRO-4471923', carrier: 'Estes Freight' },
)

// endregion:example

export { delivery }
