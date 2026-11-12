import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// A corrected number resets the carrier status to `pending`.
const delivery = await client.orders.fulfillments.deliveries.update(
  'or_UkLWZg9DAJ',
  'ful_UkLWZg9DAJ',
  'dlv_UkLWZg9DAJ',
  { tracking_number: '1Z999AA10123456784', carrier: 'UPS' },
)

// endregion:example

export { delivery }
