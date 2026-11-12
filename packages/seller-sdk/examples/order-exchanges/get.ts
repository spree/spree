import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const exchange = await client.orders.exchanges.get('or_UkLWZg9DAJ', 'exch_UkLWZg9DAJ')

// endregion:example

export { exchange }
