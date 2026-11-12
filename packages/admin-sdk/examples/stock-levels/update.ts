import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Sets the count the shelf should end at; the difference is recorded in the stock history.
const stockLevel = await client.stockLevels.update('sl_UkLWZg9DAJ', {
  count_on_hand: 42,
  reason: 'Cycle count',
})

// endregion:example

export { stockLevel }
