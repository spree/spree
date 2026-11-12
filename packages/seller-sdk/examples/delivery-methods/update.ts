import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const deliveryMethod = await client.deliveryMethods.update('dm_UkLWZg9DAJ', {
  name: 'Next day (tracked)',
  estimated_transit_business_days_min: 1,
  estimated_transit_business_days_max: 2,
})

// endregion:example

export { deliveryMethod }
