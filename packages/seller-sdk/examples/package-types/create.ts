import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const packageType = await client.packageTypes.create({
  name: 'Medium box',
  kind: 'box',
  length: 40,
  width: 30,
  height: 20,
  dimensions_unit: 'cm',
  max_weight: 10,
  weight_unit: 'kg',
})

// endregion:example

export { packageType }
