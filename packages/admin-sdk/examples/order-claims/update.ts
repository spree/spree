import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const claim = await client.orders.claims.update('or_UkLWZg9DAJ', 'claim_UkLWZg9DAJ', {
  memo: 'Photos received from the customer',
})

// endregion:example

export { claim }
