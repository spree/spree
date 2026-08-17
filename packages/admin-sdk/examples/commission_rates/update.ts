import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// `rules` is the rate's whole targeting — what you send replaces what it holds.
// `position` moves the rate: 1 is tried first, and the first match wins.
//
// Every rule has to hold, so this charges 15% only on camera sales worth 50 or
// more. Call ruleTypes() for the kinds this marketplace has.
const commissionRate = await client.commissionRates.update('crate_a1b2c3', {
  value: 15,
  position: 1,
  rules: [
    { type: 'category_rule', preferences: { category_ids: ['ctg_d4e5f6'] } },
    { type: 'item_total_rule', preferences: { min_amount: '50' } },
  ],
})

// endregion:example

export { commissionRate }
