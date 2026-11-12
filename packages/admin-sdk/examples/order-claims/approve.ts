import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const claim = await client.orders.claims.approve('or_UkLWZg9DAJ', 'claim_UkLWZg9DAJ')

// endregion:example

export { claim }
