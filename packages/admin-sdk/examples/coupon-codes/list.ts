import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: coupons } = await client.promotions.couponCodes.list('promo_UkLWZg9DAJ')
// endregion:example

export { coupons }
