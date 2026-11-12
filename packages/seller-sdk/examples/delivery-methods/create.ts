import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const deliveryMethod = await client.deliveryMethods.create({
  name: 'Next day',
  delivery_profile_id: 'fp_UkLWZg9DAJ',
  calculator: { type: 'flat_rate', preferences: { amount: '9.99', currency: 'USD' } },
})

// endregion:example

export { deliveryMethod }
