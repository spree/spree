import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const rule = await client.promotions.rules.update('promo_UkLWZg9DAJ', 'promorule_k5nR8xLq', {
  preferences: { currency: 'USD' },
})

// endregion:example

export { rule }
