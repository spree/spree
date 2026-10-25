import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Pays out everything the seller is owed now, one payout per currency.
const { data: payouts } = await client.sellers.settle('sel_UkLWZg9DAJ')

// endregion:example

export { payouts }
