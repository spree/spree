import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const giftCard = await client.customer.giftCards.get('gc_abc123', {
  token: '<token>',
})
// endregion:example

export { giftCard }
