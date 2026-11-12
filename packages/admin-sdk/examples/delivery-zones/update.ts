import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// `members` replaces the zone's full member set.
const deliveryZone = await client.deliveryZones.update('dz_UkLWZg9DAJ', {
  name: 'US East Coast',
  members: [
    {
      member_type: 'postal_code',
      country_code: 'US',
      postal_code_from: '10000',
      postal_code_to: '14999',
    },
  ],
})

// endregion:example

export { deliveryZone }
