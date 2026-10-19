import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Upload the CSV with `client.files.upload(file, { visibility: 'private' })`
// first and pass its `signed_id`. The import then waits in `mapping`, with the
// columns assigned automatically.
const productImport = await client.imports.create({
  type: 'products',
  attachment_signed_id: 'eyJfcmFpbHMiOnsiZGF0YSI6MSwicHVyIjoiYmxvYl9pZCJ9fQ==--a1b2c3',
})

// endregion:example

export { productImport }
