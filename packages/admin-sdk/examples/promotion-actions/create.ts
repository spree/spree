import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const action = await client.promotions.actions.create('promo_UkLWZg9DAJ', {
  type: 'free_shipping',
})
// endregion:example

export { action }
