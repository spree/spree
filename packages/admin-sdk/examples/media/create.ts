import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Upload the file first with `client.files.upload(file)`, then add it here.
const media = await client.media.create({
  signed_id: 'eyJfcmFpbHMiOnsiZGF0YSI6NDJ9fQ==--8f3a2c',
  alt: 'Folded on a table',
})

// endregion:example

export { media }
