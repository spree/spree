import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const { data: transfers } = await client.transfers.list({
  payout_id_eq: 'vpo_UkLWZg9DAJ',
  sort: '-created_at',
})

// endregion:example

export { transfers }
