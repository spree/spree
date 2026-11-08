import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
// `signed_id` comes from `files.upload()` with `visibility: 'private'`.
const digitalAsset = await client.products.digitalAssets.create('prod_UkLWZg9DAJ', {
  signed_id: 'eyJfcmFpbHMiOnsiZGF0YSI6MTIzfX0=--abc123',
  authorized_clicks: 5,
  authorized_days: 30,
})

// endregion:example

export { digitalAsset }
