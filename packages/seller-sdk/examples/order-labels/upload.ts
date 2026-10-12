import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const label = await client.orders.fulfillments.labels.create('or_UkLWZg9DAJ', 'ful_UkLWZg9DAJ', {
  file_signed_id: 'signed_id_from_files_upload',
  tracking_number: '1Z879E930346834440',
  cost: '6.50',
  currency: 'USD',
})

// endregion:example

export { label }
