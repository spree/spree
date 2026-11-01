import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
declare const file: Blob

const upload = await client.files.upload(file, { visibility: 'private' })
const invoice = await client.sellerPayouts.invoices.create('vpo_UkLWZg9DAJ', {
  kind: 'invoice',
  number: 'COM/2026/11/3',
  issued_on: '2026-11-01',
  total: '12.30',
  file_signed_id: upload.signed_id,
})

// endregion:example

export { invoice }
