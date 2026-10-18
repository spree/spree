import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Records that the bank transfer went out.
const payout = await client.sellerPayouts.complete('vpo_UkLWZg9DAJ', {
  reference: 'BANK-TRF-20261012-0042',
})

// endregion:example

export { payout }
