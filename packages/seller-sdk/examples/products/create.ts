import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const product = await client.products.create({
  name: 'Hand-thrown mug',
  description: '<p>Stoneware, glazed by hand.</p>',
  prices: [{ currency: 'USD', amount: '24.00' }],
})

// endregion:example

export { product }
