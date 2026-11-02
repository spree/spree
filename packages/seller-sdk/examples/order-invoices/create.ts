import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
declare const file: Blob

const upload = await client.files.upload(file, { visibility: 'private' })
const invoice = await client.orders.invoices.create('or_UkLWZg9DAJ', {
  kind: 'invoice',
  number: 'S-17',
  issued_on: '2026-11-01',
  total: '123.00',
  file_signed_id: upload.signed_id,
})

// endregion:example

export { invoice }
