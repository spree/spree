import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: actions } = await client.promotions.actions.list('promo_UkLWZg9DAJ')
// endregion:example

export { actions }
