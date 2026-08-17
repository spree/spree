import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// `rules` is the rate's whole targeting — what you send replaces what it holds.
// `position` moves the rate: 1 is tried first, and the first match wins.
const commissionRate = await client.commissionRates.update('crate_a1b2c3', {
  value: 15,
  position: 1,
  rules: [{ subject_type: 'Spree::Category', subject_id: 'ctg_d4e5f6' }],
})

// endregion:example

export { commissionRate }
