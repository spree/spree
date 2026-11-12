import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const product = await client.products.update('prod_UkLWZg9DAJ', {
  name: 'Hand-thrown mug, large',
})

// endregion:example

export { product }
