import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const profile = await client.deliveryProfiles.update('fp_86Rf07xd4z', {
  name: 'Oversized freight',
  stock_location_ids: [],
})

// endregion:example

export { profile }
