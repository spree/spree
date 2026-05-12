import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const wishlists = await client.wishlists.list({}, {
  token: '<token>',
})
// endregion:example

export { wishlists }
