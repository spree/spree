import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const fulfillment = await client.orders.fulfillments.fulfill('or_UkLWZg9DAJ', 'ful_UkLWZg9DAJ', {
  tracking: '1Z879E930346834440',
  tracking_carrier: 'ups',
  notify_customer: true,
})

// endregion:example

export { fulfillment }
