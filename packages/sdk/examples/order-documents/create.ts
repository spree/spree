import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
declare const file: Blob

const upload = await client.orders.documents.upload('or_abc123', file, {}, { token: '<token>' })
const document = await client.orders.documents.create(
  'or_abc123',
  { label: 'Purchase order 4471', file_signed_id: upload.signed_id },
  { token: '<token>' },
)

// endregion:example

export { document }
