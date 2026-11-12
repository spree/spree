import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const stockLocation = await client.stockLocations.get('sloc_UkLWZg9DAJ')

// endregion:example

export { stockLocation }
