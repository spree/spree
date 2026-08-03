import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const { data: pickupLocations } = await client.deliveryMethods.pickupLocations('dm_abc123', {
  cart_id: 'cart_abc123',
})

// endregion:example

export { pickupLocations }
