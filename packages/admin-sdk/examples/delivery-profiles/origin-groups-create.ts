import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const originGroup = await client.deliveryProfiles.originGroups.create('fp_86Rf07xd4z', {
  name: 'EU warehouse',
  stock_location_ids: ['sloc_86Rf07xd4z'],
})

// endregion:example

export { originGroup }
