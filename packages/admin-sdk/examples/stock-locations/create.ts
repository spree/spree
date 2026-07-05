import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const stockLocation = await client.stockLocations.create({
  name: 'Brooklyn warehouse',
  kind: 'warehouse',
  country_iso: 'US',
  state_abbr: 'NY',
  city: 'Brooklyn',
  zipcode: '11201',
  pickup_enabled: true,
  pickup_stock_policy: 'local',
  pickup_ready_in_minutes: 60,
})
// endregion:example

export { stockLocation }
