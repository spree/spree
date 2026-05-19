import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: giftCards } = await client.giftCards.list({
  page: 1,
  limit: 25,
  expand: ['customer', 'created_by'],
})
// endregion:example

export { giftCards }
