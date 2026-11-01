import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
declare const file: Blob

const upload = await client.files.upload(file, { visibility: 'private' })
const document = await client.orders.documents.create('or_UkLWZg9DAJ', {
  label: 'Technical specification',
  customer_visible: true,
  file_signed_id: upload.signed_id,
})

// endregion:example

export { document }
