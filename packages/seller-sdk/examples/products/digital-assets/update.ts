import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
// `null` falls back to the marketplace's download settings.
const digitalAsset = await client.products.digitalAssets.update(
  'prod_UkLWZg9DAJ',
  'dig_k5nR8xLqPz',
  { authorized_clicks: 10, authorized_days: null },
)

// endregion:example

export { digitalAsset }
