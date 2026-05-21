import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const subscriber = await client.newsletterSubscribers.verify({
  token: 'abc123def456',
})
// endregion:example

export { subscriber }
