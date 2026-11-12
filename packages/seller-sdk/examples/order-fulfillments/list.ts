import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const { data: fulfillments } = await client.orders.fulfillments.list('or_UkLWZg9DAJ')

// endregion:example

export { fulfillments }
