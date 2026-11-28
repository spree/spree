import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
declare const file: Blob

const upload = await client.files.upload(file, { visibility: 'private' })
const invoice = await client.orders.invoices.create('or_UkLWZg9DAJ', {
  kind: 'invoice',
  number: 'FV/2026/11/42',
  issued_on: '2026-11-01',
  total: '123.00',
  net_total: '100.00',
  tax_total: '23.00',
  file_signed_id: upload.signed_id,
})

// endregion:example

export { invoice }
