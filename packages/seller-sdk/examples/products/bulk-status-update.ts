import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const result = await client.products.bulkStatusUpdate({
  ids: ['prod_UkLWZg9DAJ', 'prod_9XbR2kQwLm'],
  status: 'archived',
})

// endregion:example

export { result }
