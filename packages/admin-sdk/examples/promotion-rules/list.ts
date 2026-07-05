import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: rules } = await client.promotions.rules.list('promo_UkLWZg9DAJ')
// endregion:example

export { rules }
