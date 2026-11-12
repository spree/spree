import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const claim = await client.orders.claims.deny('or_UkLWZg9DAJ', 'claim_UkLWZg9DAJ', {
  reason: 'Damage is not covered after 30 days',
})

// endregion:example

export { claim }
