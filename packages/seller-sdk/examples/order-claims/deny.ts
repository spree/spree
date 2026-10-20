import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const claim = await client.orders.claims.deny('or_UkLWZg9DAJ', 'claim_UkLWZg9DAJ', {
  reason: 'Reported after the claim window closed',
})

// endregion:example

export { claim }
