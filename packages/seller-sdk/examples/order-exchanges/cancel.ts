import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const exchange = await client.orders.exchanges.cancel('or_UkLWZg9DAJ', 'exch_UkLWZg9DAJ', {
  reason: 'Customer kept the original',
})

// endregion:example

export { exchange }
