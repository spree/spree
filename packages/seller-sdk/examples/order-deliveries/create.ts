import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const delivery = await client.orders.fulfillments.deliveries.create(
  'or_UkLWZg9DAJ',
  'ful_UkLWZg9DAJ',
  {
    tracking_number: '1Z879E930346834440',
    carrier: 'ups',
  },
)

// endregion:example

export { delivery }
