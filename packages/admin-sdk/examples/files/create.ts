import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Returns where to send the bytes: send the file to `upload.url` with
// `upload.method` and `upload.headers`, then pass `signed_id` to the
// endpoint that uses it.
// `client.files.upload(file)` does both steps for you.
const { signed_id, upload } = await client.files.create({
  filename: 'products.csv',
  content_type: 'text/csv',
  byte_size: 48213,
  checksum: 'XrY7u+Ae7tCTyyK7j1rNww==',
  visibility: 'private',
})

// endregion:example

export { signed_id, upload }
