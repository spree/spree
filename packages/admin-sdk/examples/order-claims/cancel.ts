import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const claim = await client.orders.claims.cancel('or_UkLWZg9DAJ', 'claim_UkLWZg9DAJ', {
  reason: 'Opened by mistake',
})

// endregion:example

export { claim }
