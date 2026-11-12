import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const { data: payouts } = await client.payouts.list({
  status_eq: 'completed',
  sort: '-period_end',
})

// endregion:example

export { payouts }
