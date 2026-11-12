import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const orderReturn = await client.orders.returns.refund('or_UkLWZg9DAJ', 'ret_UkLWZg9DAJ', {
  refund_method: 'original_payment',
})

// endregion:example

export { orderReturn }
