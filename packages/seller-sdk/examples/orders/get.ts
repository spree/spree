import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const order = await client.orders.get('or_UkLWZg9DAJ', { expand: ['payment_splits'] })

// endregion:example

export { order }
