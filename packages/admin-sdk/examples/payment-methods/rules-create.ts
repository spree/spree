import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Offer this method only on orders of 5,000.00 USD or more:
const rule = await client.paymentMethods.rules.create('pm_UkLWZg9DAJ', {
  type: 'order_total_rule',
  preferences: { min_totals: { USD: '5000.00' } },
})

// endregion:example

export { rule }
