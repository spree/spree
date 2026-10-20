import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const action = await client.promotions.actions.update('promo_UkLWZg9DAJ', 'pact_k5nR8xLqPz', {
  calculator: { type: 'percent_on_line_item', preferences: { percent: '15' } },
})

// endregion:example

export { action }
