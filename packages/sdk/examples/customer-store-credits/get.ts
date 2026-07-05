import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const credit = await client.customer.storeCredits.get('credit_abc123', {
  token: '<token>',
})
// endregion:example

export { credit }
