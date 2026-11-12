import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: originGroups } = await client.deliveryProfiles.originGroups.list('fp_86Rf07xd4z')

// endregion:example

export { originGroups }
