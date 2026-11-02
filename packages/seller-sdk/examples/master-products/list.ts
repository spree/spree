import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const { data: products, meta } = await client.masterProducts.list({
  sort: 'name',
  limit: 25,
})

// endregion:example

export { meta, products }
