import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const { data: pickupMethods } = await client.deliveryMethods.list({
  fulfillment_type: 'pickup',
})

// endregion:example

export { pickupMethods }
