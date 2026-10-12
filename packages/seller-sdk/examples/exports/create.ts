import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const exp = await client.exports.create({
  type: 'orders',
  search_params: { completed_at_gt: '2026-01-01' },
})

// endregion:example

export { exp }
