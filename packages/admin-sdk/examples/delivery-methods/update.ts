import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const deliveryMethod = await client.deliveryMethods.update('dm_UkLWZg9DAJ', {
  name: 'UPS Express',
  estimated_transit_business_days_min: 1,
  estimated_transit_business_days_max: 2,
})

// endregion:example

export { deliveryMethod }
