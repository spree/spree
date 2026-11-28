import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const comment = await client.orders.activities.create('or_UkLWZg9DAJ', {
  body: 'Customer asked to hold the parcel until Monday.',
})

// endregion:example

export { comment }
