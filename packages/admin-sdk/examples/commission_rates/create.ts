import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Charges this seller 12.5% of every sale, with VAT on the commission itself
// left to your tax settings.
const commissionRate = await client.commissionRates.create({
  name: 'Audio sellers',
  kind: 'percentage',
  value: 12.5,
  priority: 10,
  rules: [{ subject_type: 'Spree::Vendor', subject_id: 'ven_a1b2c3' }],
})

// endregion:example

export { commissionRate }
