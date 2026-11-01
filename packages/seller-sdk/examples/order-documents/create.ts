import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
declare const file: Blob

const upload = await client.files.upload(file, { visibility: 'private' })
const document = await client.orders.documents.create('or_UkLWZg9DAJ', {
  label: 'CMR consignment note',
  file_signed_id: upload.signed_id,
})

// endregion:example

export { document }
