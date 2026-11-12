import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// `signed_id` comes from `files.upload()` with `visibility: 'private'`.
const digitalAsset = await client.products.digitalAssets.create('prod_86Rf07xd4z', {
  signed_id: 'eyJfcmFpbHMiOnsiZGF0YSI6MTIzfX0=--abc123',
  authorized_clicks: 5,
  authorized_days: 30,
})

// endregion:example

export { digitalAsset }
