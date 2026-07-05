import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const cards = await client.customer.creditCards.list({}, {
  token: '<token>',
})
// endregion:example

export { cards }
