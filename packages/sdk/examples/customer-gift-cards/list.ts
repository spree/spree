import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const giftCards = await client.customer.giftCards.list({}, {
  token: '<token>',
})
// endregion:example

export { giftCards }
