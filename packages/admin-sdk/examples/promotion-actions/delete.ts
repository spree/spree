import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
await client.promotions.actions.delete('promo_UkLWZg9DAJ', 'promoact_k5nR8xLq')
// endregion:example
