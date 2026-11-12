import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const file = await client.files.create({
  filename: 'registration.pdf',
  content_type: 'application/pdf',
  byte_size: 51234,
  visibility: 'private',
})

// endregion:example

export { file }
