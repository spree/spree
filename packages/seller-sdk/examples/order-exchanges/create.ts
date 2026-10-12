import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const exchange = await client.orders.exchanges.create('or_UkLWZg9DAJ', {
  items: [
    { fulfillment_item_id: 'fi_UkLWZg9DAJ', new_variant_id: 'variant_86Rf07xd4z', quantity: 1 },
  ],
  reason_id: 'rar_UkLWZg9DAJ',
})

// endregion:example

export { exchange }
