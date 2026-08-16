import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Stops a trading vendor from selling. Their catalog and history stay, and
// approving reinstates them.
const vendor = await client.vendors.suspend('ven_UkLWZg9DAJ', {
  reason: 'Counterfeit goods',
})

// endregion:example

export { vendor }
