import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const delivery = await client.orders.fulfillments.deliveries.update(
  'or_UkLWZg9DAJ',
  'ful_UkLWZg9DAJ',
  'dlv_UkLWZg9DAJ',
  { tracking_number: '1Z879E930346834441' },
)

// endregion:example

export { delivery }
