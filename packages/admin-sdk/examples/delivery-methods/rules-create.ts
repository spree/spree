import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Offer this method only on orders of 50.00 or more:
const rule = await client.deliveryMethods.rules.create('dm_UkLWZg9DAJ', {
  type: 'item_total_rule',
  preferences: { minimum_amount: '50.00' },
})

// endregion:example

export { rule }
