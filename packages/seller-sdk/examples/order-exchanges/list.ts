import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const { data: exchanges } = await client.orders.exchanges.list('or_UkLWZg9DAJ')

// endregion:example

export { exchanges }
