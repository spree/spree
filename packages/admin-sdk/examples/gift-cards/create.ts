import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const giftCard = await client.giftCards.create({
  amount: '25.00',
  currency: 'USD',
  expires_at: '2030-12-31',
  user_id: 'cus_UkLWZg9DAJ',
})
// endregion:example

export { giftCard }
