import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const profile = await client.deliveryProfiles.create({
  name: 'Oversized',
  stock_location_ids: ['sloc_86Rf07xd4z'],
})

// endregion:example

export { profile }
