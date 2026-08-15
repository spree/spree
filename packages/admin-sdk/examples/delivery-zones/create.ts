import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const deliveryZone = await client.deliveryZones.create({
  name: 'US North-East',
  members: [
    { member_type: 'country', country_code: 'US' },
    { member_type: 'postal_code', country_code: 'US', postal_code_prefix: '10' },
  ],
})

// endregion:example

export { deliveryZone }
