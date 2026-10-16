import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const { data: orders, meta } = await client.orders.list({
  fulfillment_status_eq: 'unfulfilled',
  sort: '-completed_at',
  limit: 25,
})

// endregion:example

export { meta, orders }
