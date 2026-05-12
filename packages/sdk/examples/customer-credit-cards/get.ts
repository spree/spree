import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const card = await client.customer.creditCards.get('card_abc123', {
  token: '<token>',
})
// endregion:example

export { card }
