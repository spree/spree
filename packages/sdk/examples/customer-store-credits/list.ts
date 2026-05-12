import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const credits = await client.customer.storeCredits.list({}, {
  token: '<token>',
})
// endregion:example

export { credits }
