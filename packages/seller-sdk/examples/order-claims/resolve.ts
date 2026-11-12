import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const claim = await client.orders.claims.resolve('or_UkLWZg9DAJ', 'claim_UkLWZg9DAJ', {
  resolution: 'refund',
  refund_method: 'original_payment',
  amount: '19.99',
})

// endregion:example

export { claim }
