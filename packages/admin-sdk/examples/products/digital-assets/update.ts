import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// `null` falls back to the store's download settings.
const digitalAsset = await client.products.digitalAssets.update(
  'prod_86Rf07xd4z',
  'dig_k5nR8xLqPz',
  { authorized_clicks: 10, authorized_days: null },
)

// endregion:example

export { digitalAsset }
