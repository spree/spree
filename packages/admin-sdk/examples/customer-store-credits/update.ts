import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const credit = await client.customers.storeCredits.update(
  'cus_UkLWZg9DAJ',
  'sc_UkLWZg9DAJ',
  { memo: 'Reissued for damaged shipment' },
)
// endregion:example

export { credit }
