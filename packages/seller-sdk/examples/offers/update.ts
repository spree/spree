import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const offer = await client.variants.update('variant_UkLWZg9DAJ', {
  prices: [{ currency: 'USD', amount: '16.50' }],
})

// endregion:example

export { offer }
