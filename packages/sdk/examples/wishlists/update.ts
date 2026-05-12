import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const wishlist = await client.wishlists.update('wl_abc123', {
  name: 'Updated Name',
}, {
  token: '<token>',
})
// endregion:example

export { wishlist }
