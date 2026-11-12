import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const { data: fulfillments } = await client.orders.fulfillments.split(
  'or_UkLWZg9DAJ',
  'ful_UkLWZg9DAJ',
  {
    variant_id: 'variant_86Rf07xd4z',
    quantity: 1,
  },
)

// endregion:example

export { fulfillments }
