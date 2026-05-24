import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const giftCard = await client.giftCards.update('gc_K3zr8x', {
  amount: '75.00',
})
// endregion:example

export { giftCard }
