import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// One row per currency: earned, paid, still owed, and not yet confirmed.
const { data: balances } = await client.sellers.balances('sel_UkLWZg9DAJ')

// endregion:example

export { balances }
