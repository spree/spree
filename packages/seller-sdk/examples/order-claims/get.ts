import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const claim = await client.orders.claims.get('or_UkLWZg9DAJ', 'claim_UkLWZg9DAJ')

// endregion:example

export { claim }
