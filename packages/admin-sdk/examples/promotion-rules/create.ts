import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const rule = await client.promotions.rules.create('promo_UkLWZg9DAJ', {
  type: 'currency',
  preferences: { currency: 'EUR' },
})
// endregion:example

export { rule }
