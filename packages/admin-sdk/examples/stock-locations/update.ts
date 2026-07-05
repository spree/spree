import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const stockLocation = await client.stockLocations.update('sloc_UkLWZg9DAJ', {
  pickup_enabled: true,
  pickup_ready_in_minutes: 45,
  pickup_instructions: 'Enter through the back door, ring the bell.',
})
// endregion:example

export { stockLocation }
