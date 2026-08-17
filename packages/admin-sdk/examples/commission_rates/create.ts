import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Charges this seller 12.5% of every sale, with VAT on the commission itself
// left to your tax settings. The rate lands at the top of the list, so it
// resolves ahead of anything more general already there.
const commissionRate = await client.commissionRates.create({
  name: 'Audio sellers',
  kind: 'percentage',
  value: 12.5,
  rules: [{ type: 'seller_rule', preferences: { seller_ids: ['sel_a1b2c3'] } }],
})

// endregion:example

export { commissionRate }
