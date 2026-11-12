import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const order = await client.orders.cancel('or_UkLWZg9DAJ', {
  cancel_reason_id: 'ocr_UkLWZg9DAJ',
  cancel_note: 'Out of stock with the supplier',
  refund_payments: true,
})

// endregion:example

export { order }
