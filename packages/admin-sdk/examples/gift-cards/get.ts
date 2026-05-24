import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const giftCard = await client.giftCards.get('gc_K3zr8x', {
  expand: ['customer', 'created_by', 'orders'],
})
// endregion:example

export { giftCard }
