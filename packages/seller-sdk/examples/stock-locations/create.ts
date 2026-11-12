import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const stockLocation = await client.stockLocations.create({
  name: 'Brooklyn warehouse',
  kind: 'warehouse',
  country_code: 'US',
  state_code: 'NY',
  city: 'Brooklyn',
  zipcode: '11201',
})

// endregion:example

export { stockLocation }
