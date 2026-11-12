import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const deliveryMethod = await client.deliveryMethods.get('dm_UkLWZg9DAJ')

// endregion:example

export { deliveryMethod }
