import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const order = await client.orders.address('or_UkLWZg9DAJ', {
  shipping_address: { address1: '9 Corrected Way', city: 'Portland', postal_code: '97201' },
})

// endregion:example

export { order }
